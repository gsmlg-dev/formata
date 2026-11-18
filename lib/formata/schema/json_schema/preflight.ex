defmodule Formata.Schema.JSONSchema.Preflight do
  @moduledoc false
  alias Formata.Error
  alias Formata.Schema.JSONSchema
  alias Formata.JSONSchema.{ResourceContext, SchemaTraversal, URIUtil}

  @limits [
    max_depth: 128,
    max_nodes: 100_000,
    max_bytes: 1_048_576,
    max_refs: 10_000,
    max_resources: 1_000
  ]
  @compile_options [:dialect, :format_assertion, :content_assertion, :loader, :base_uri]

  def check(document, opts) do
    guarded(fn ->
      state = state(opts)
      if :erlang.external_size(document) > state.limits[:max_bytes], do: limit(:max_bytes)
      bound(document, 0, state)
      with {:ok, _} <- JSONSchema.compile(document, Keyword.take(opts, @compile_options)), do: :ok
    end)
  end

  def preflight(document, opts) do
    guarded(fn ->
      state = state(opts)

      opts =
        Keyword.put_new(
          opts,
          :dialect,
          if(draft(document, opts) == "draft7", do: :draft7, else: :draft2020_12)
        )

      state = scan_document(document, Keyword.get(opts, :base_uri), %{state | opts: opts})
      state = audit(state)
      cache = state.resources

      loader = fn uri ->
        case Map.fetch(cache, URIUtil.base(uri)) do
          {:ok, {doc, initial}} -> {:ok, %{document: doc, base_uri: initial}}
          :error -> {:error, :unregistered_resource}
        end
      end

      JSONSchema.compile(
        document,
        Keyword.put(Keyword.take(opts, @compile_options), :loader, loader)
      )
    end)
  end

  def validate_meta(document, opts) do
    draft = draft(document, opts)

    {module, uri} =
      if draft == "draft7",
        do: {Formata.JSONSchema.Draft7.Schemas, "http://json-schema.org/draft-07/schema#"},
        else:
          {Formata.JSONSchema.Draft202012.Schemas, "https://json-schema.org/draft/2020-12/schema"}

    {:ok, meta} = module.fetch(uri)
    {:ok, compiled} = Formata.JSONSchema.compile(meta, draft: draft, format_assertion: true)

    case Formata.JSONSchema.validate(compiled, document) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error,
         errors
         |> Enum.map(fn error ->
           path = Enum.reverse(error.path || [])

           Error.new(
             :schema,
             if(path == ["type"], do: :invalid_keyword_value, else: :invalid_schema),
             Formata.JSONSchema.format_error(%{error | path: []}),
             backend: JSONSchema,
             schema_path: path,
             cause: error
           )
         end)
         |> Enum.uniq_by(&{&1.schema_path, &1.code})}
    end
  end

  defp state(opts) do
    specs =
      Enum.map(@limits, fn {key, _} ->
        {key, &(is_integer(&1) and &1 >= 0), "a nonnegative integer"}
      end) ++
        [
          {:registry,
           &(is_map(&1) and not is_struct(&1) and
               Enum.all?(Map.keys(&1), fn key -> is_binary(key) end)), "a URI-to-schema map"},
          {:loader, &is_function(&1, 1), "a one-argument loader"},
          {:dialect, &(&1 in [:draft7, :draft2020_12]), ":draft7 or :draft2020_12"},
          {:base_uri, &is_binary/1, "a URI string"},
          {:format_assertion, &is_boolean/1, "a boolean"},
          {:content_assertion, &is_boolean/1, "a boolean"}
        ]

    require_ok(Formata.Codec.check_options(opts, specs, backend: JSONSchema))

    %{
      opts: opts,
      limits: Keyword.merge(@limits, Keyword.take(opts, Keyword.keys(@limits))),
      nodes: 0,
      resource_count: 0,
      ref_count: 0,
      resources: %{},
      anchors: %{},
      owner_paths: %{},
      pending: [],
      seen: MapSet.new()
    }
  end

  defp bound(document, depth, state) do
    if depth > state.limits[:max_depth], do: limit(:max_depth)
    if state.nodes >= state.limits[:max_nodes], do: limit(:max_nodes)
    state = %{state | nodes: state.nodes + 1}

    cond do
      is_map(document) -> Enum.reduce(Map.values(document), state, &bound(&1, depth + 1, &2))
      is_list(document) -> Enum.reduce(document, state, &bound(&1, depth + 1, &2))
      true -> state
    end
  end

  defp scan_document(document, initial, state) do
    if :erlang.external_size(document) > state.limits[:max_bytes], do: limit(:max_bytes)
    state = bound(document, 0, state)
    require_ok(JSONSchema.check_json_document(document))
    require_ok(validate_meta(document, state.opts))
    state = count_resource(state)
    state = put_resource(state, URIUtil.base(initial || ""), {document, initial})
    scan(document, initial, [], state)
  end

  defp scan(document, initial, path, state) do
    pointer = Formata.JSONPointer.encode_path(path, format: "uri_fragment")
    selected_draft = draft(document, state.opts)

    {:ok, context} =
      ResourceContext.resolve(document, initial, URIUtil.fragment(pointer), draft: selected_draft)

    node = context.target
    base = node_base(node, context.inherited_base, selected_draft)

    owner_uri =
      node_base(context.resource, context.resource_base, selected_draft)
      |> then(&URIUtil.base(&1 || ""))

    location = {initial, owner_uri}

    owner_path =
      case Map.fetch(state.owner_paths, location) do
        {:ok, prefix} -> prefix
        :error -> resource_path(document, initial, path, context.resource, selected_draft)
      end

    state = %{state | owner_paths: Map.put(state.owner_paths, location, owner_path)}

    state =
      if context.resource === node and is_map(node) and is_binary(node["$id"]) and
           URIUtil.base(node["$id"]) != "" and
           not (selected_draft == "draft7" and Map.has_key?(node, "$ref")),
         do: register_id(state, URIUtil.base(base || ""), node, context.inherited_base),
         else: state

    key = {owner_uri, Enum.drop(path, length(owner_path))}

    if MapSet.member?(state.seen, key) do
      state
    else
      state = %{state | seen: MapSet.put(state.seen, key)}

      state =
        Enum.reduce(["$anchor", "$dynamicAnchor"], state, fn keyword, acc ->
          if draft(document, state.opts) != "draft7" and is_map(node) and is_binary(node[keyword]),
            do:
              register_anchor(
                acc,
                URIUtil.join_fragment(base || "", node[keyword]),
                {document, initial, path}
              ),
            else: acc
        end)

      state =
        if draft(document, state.opts) == "draft7" and is_map(node) and is_binary(node["$id"]) and
             is_binary(URIUtil.fragment(base)) and not Map.has_key?(node, "$ref"),
           do: register_anchor(state, base, {document, initial, path}),
           else: state

      state =
        Enum.reduce(["$ref", "$dynamicRef"], state, fn keyword, acc ->
          if is_map(node) and is_binary(node[keyword]) and
               (keyword == "$ref" or draft(document, state.opts) != "draft7") do
            if acc.ref_count >= acc.limits[:max_refs], do: limit(:max_refs)

            ref = %{
              ref: node[keyword],
              path: path ++ [keyword],
              base: base,
              owner: {context.resource, context.resource_base}
            }

            %{acc | ref_count: acc.ref_count + 1, pending: [ref | acc.pending]}
          else
            acc
          end
        end)

      Enum.reduce(
        SchemaTraversal.scope_subschemas_with_paths(node, draft(document, state.opts)),
        state,
        fn {suffix, _child}, acc -> scan(document, initial, path ++ suffix, acc) end
      )
    end
  end

  defp node_base(%{"$ref" => _}, inherited, "draft7"), do: inherited

  defp node_base(%{"$id" => id}, inherited, _draft) when is_binary(id),
    do: URIUtil.resolve(inherited, id)

  defp node_base(_node, inherited, _draft), do: inherited

  # Find the owning resource's pointer once per retrieval URI/resource pair.
  # This gives the same identity when an embedded resource is revisited directly.
  defp resource_path(document, initial, path, owner, selected_draft) do
    Enum.find_value(0..length(path), fn count ->
      prefix = Enum.take(path, count)
      pointer = Formata.JSONPointer.encode_path(prefix, format: "uri_fragment")

      case ResourceContext.resolve(document, initial, URIUtil.fragment(pointer),
             draft: selected_draft
           ) do
        {:ok, %{target: ^owner}} -> {:found, prefix}
        _ -> nil
      end
    end)
    |> elem(1)
  end

  defp register_anchor(state, uri, entry) do
    case Map.fetch(state.anchors, uri) do
      {:ok, ^entry} -> state
      {:ok, _} -> fail(:invalid_schema, [], "duplicate anchor identifier #{uri}")
      :error -> %{state | anchors: Map.put(state.anchors, uri, entry)}
    end
  end

  defp register_id(state, key, document, initial) do
    case Map.fetch(state.resources, key) do
      {:ok, {^document, _}} ->
        state

      {:ok, _} ->
        fail(:invalid_schema, [], "duplicate resource identifier #{key}")

      :error ->
        alias? =
          Enum.any?(state.resources, fn {_uri, {doc, base}} ->
            doc === document and base == initial
          end)

        state = if alias?, do: state, else: count_resource(state)
        put_resource(state, key, {document, initial})
    end
  end

  defp put_resource(state, key, value) do
    case Map.fetch(state.resources, key) do
      {:ok, ^value} -> state
      {:ok, _} -> fail(:invalid_schema, [], "conflicting resource at #{key}")
      :error -> %{state | resources: Map.put(state.resources, key, value)}
    end
  end

  defp count_resource(state) do
    if state.resource_count >= state.limits[:max_resources], do: limit(:max_resources)
    %{state | resource_count: state.resource_count + 1}
  end

  defp audit(%{pending: []} = state), do: state

  defp audit(%{pending: [ref | rest]} = state) do
    state = %{state | pending: rest}
    uri = URIUtil.resolve(ref.base, ref.ref)
    {base, fragment} = URIUtil.split_fragment(uri)

    state =
      if Map.has_key?(state.resources, base) or String.starts_with?(ref.ref, "#") or ref.ref == "",
        do: state,
        else: load(base, ref, state)

    {document, initial} =
      if String.starts_with?(ref.ref, "#") or ref.ref == "",
        do: ref.owner,
        else: Map.fetch!(state.resources, base)

    state =
      cond do
        is_nil(fragment) or String.starts_with?(fragment, "/") ->
          case ResourceContext.resolve(document, initial, fragment,
                 draft: draft(document, state.opts)
               ) do
            {:ok, %{target: target}} when is_map(target) or is_boolean(target) ->
              require_ok(validate_meta(target, state.opts))

              {:ok, path} =
                Formata.JSONPointer.decode_path(if(fragment, do: "#" <> fragment, else: "#"))

              scan(document, initial, path, state)

            _ ->
              unresolved(ref, uri)
          end

        true ->
          case Map.fetch(state.anchors, URIUtil.join_fragment(base, URI.decode(fragment))) do
            {:ok, {doc, init, path}} -> scan(doc, init, path, state)
            :error -> unresolved(ref, uri)
          end
      end

    audit(state)
  end

  defp load(uri, ref, state) do
    if state.resource_count >= state.limits[:max_resources], do: limit(:max_resources)
    if state.nodes >= state.limits[:max_nodes], do: limit(:max_nodes)
    registry = Keyword.get(state.opts, :registry, %{})

    result =
      case Map.fetch(registry, uri) do
        {:ok, document} ->
          {:ok, document}

        :error ->
          case builtin(uri) do
            {:ok, _} = found ->
              found

            :error ->
              case Keyword.get(state.opts, :loader) do
                nil -> {:error, :missing_loader}
                fun -> call_loader(fun, uri)
              end
          end
      end

    case result do
      {:ok, %{document: document} = wrapper} ->
        base = Map.get(wrapper, :base_uri, uri)

        if not is_binary(base),
          do: fail(:unresolved_ref, ref.path, "loader base_uri must be a string")

        scan_document(document, base, state) |> put_resource(uri, {document, base})

      {:ok, document} when is_map(document) or is_boolean(document) ->
        scan_document(document, uri, state)

      other ->
        fail(:unresolved_ref, ref.path, "schema reference could not be loaded: #{uri}", %{
          reference: ref.ref,
          reason: other
        })
    end
  end

  defp builtin(uri) do
    case Formata.JSONSchema.Draft202012.Schemas.fetch(uri) do
      :error -> Formata.JSONSchema.Draft7.Schemas.fetch(uri)
      found -> found
    end
  end

  defp call_loader(fun, uri) do
    fun.(uri)
  rescue
    error -> {:error, error}
  end

  defp draft(document, opts) do
    cond do
      opts[:dialect] == :draft7 ->
        "draft7"

      opts[:dialect] == :draft2020_12 ->
        "draft2020_12"

      is_map(document) and is_binary(document["$schema"]) and
          String.contains?(document["$schema"], "draft-07") ->
        "draft7"

      true ->
        "draft2020_12"
    end
  end

  defp unresolved(ref, uri),
    do:
      fail(:unresolved_ref, ref.path, "schema reference could not be resolved: #{uri}", %{
        reference: ref.ref,
        uri: uri
      })

  defp limit(name),
    do: fail(:limit_exceeded, [], "registration limit exceeded: #{name}", %{limit: name})

  defp fail(code, path, message, details \\ %{}),
    do:
      throw(
        {:preflight,
         [
           Error.new(:schema, code, message,
             backend: JSONSchema,
             schema_path: path,
             details: details
           )
         ]}
      )

  defp require_ok(:ok), do: :ok
  defp require_ok({:error, errors}), do: throw({:preflight, errors})

  defp guarded(fun) do
    fun.()
  catch
    {:preflight, errors} -> {:error, errors}
  end
end
