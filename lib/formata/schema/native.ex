defmodule Formata.Schema.Native do
  @moduledoc """
  Native schemas: `Formata.Backplane.Schema` definitions used through Formata.

  ## Creating schemas

  A native schema is plain Elixir data in the `Formata.Backplane.Schema` vocabulary:

      definition = %{
        name: {:required, {:string, min: 1}},
        age: {:integer, gte: 0},
        role: {:enum, ["admin", "member"]},
        tags: {:list, :string},
        address: %{city: {:required, :string}}
      }

      {:ok, schema} = Formata.Schema.native(definition)

  Atom schema keys match atom or string data keys, so the definition above
  validates string-keyed documents decoded by Formata.

  ### Reusable definitions

  Because definitions are data, they can be bound to variables and composed
  (`merge/2`, `select/2`, `except/2` delegate to `Formata.Backplane.Schema`). Named,
  reusable and recursive definitions use `Formata.Backplane.Schema.defschema/3` and
  `{:ref, {Module, name}}`:

      defmodule MyApp.Schemas do
        import Formata.Backplane.Schema

        defschema :address, %{city: {:required, :string}}
        defschema :person, %{
          name: {:required, :string},
          address: {:ref, :address},
          friends: {:list, {:ref, :person}}
        }
      end

      {:ok, schema} = Formata.Schema.native({:ref, {MyApp.Schemas, :person}})

  ## Pure validation (`Formata.validate/3`)

  `Formata.Backplane.Schema.validate/3` both validates and transforms (defaults,
  coercion, transforms, and strict-mode stripping/renaming of keys). Formata's
  pure validation therefore runs a preflight over the definition, including
  every reachable `{:ref, ...}` target, and supports this non-transforming
  subset:

    * primitive types, `{:literal, v}`, `{:enum, ...}`, `{:required, ...}`,
      `{:meta, ...}`
    * string/integer/float constraints (`min`, `max`, `regex`, `eq`, `neq`,
      `gt`, `gte`, `lt`, `lte`, `range`, `multiple_of`)
    * nested maps, keyword schemas, `{:list, ...}`, `{:map, ...}`,
      `{:tuple, ...}`, `{:schema, ...}` (including `:additional_keys`)
    * `{:either, ...}`, `{:oneof, ...}` (first matching branch, native
      semantics), `{:multi, ...}`, `{:cond, ...}`, `{:dependent, field, check, type}`
    * `{:custom, ...}` validators that return `:ok` or `{:error, ...}`
    * `{:ref, {Module, name}}`, including recursive references

  These constructs are rejected before anything runs, with an `:unsupported` /
  `:pure_validation_unsupported` error naming the construct and its schema
  path: `{type, {:default, _}}`, `{type, {:transform, _}}`,
  `{type, {:encode, _}}`, every `{:coerce, ...}` form, and the dynamic
  `{:dependent, callback}` forms (their schemas are only known at run time).
  Use `Formata.cast/3` for those.

  Custom validators run inside the native engine. If one returns anything
  other than `:ok` or an error during pure validation (for example `{:ok, new_value}`),
  validation fails with `:unsupported` / `:non_pure_custom` instead of
  accepting a modified value.

  The input is never modified, and `validate` returns only `:ok` or errors.

  ### Absent versus `nil`

  The native engine treats an explicit `nil` like an absent field: an
  optional field accepts both, and `{:required, type}` rejects both.

  ## Unknown fields

  | Option             | `validate/3`        | `cast/3`                         |
  | ------------------ | ------------------- | -------------------------------- |
  | `unknown: :allow`  | default; ignored    | kept in the result               |
  | `unknown: :reject` | `:unknown_field` error per field | `:unknown_field` error per field |
  | `unknown: :strip`  | not accepted        | default; removed from the result |

  Unknown-field rejection is enforced by the native engine (Formata adds an
  `:additional_keys` rule to each map schema). It is not available for keyword
  list schemas.

  ## Casting (`Formata.cast/3`)

  `cast` runs the full native engine (`Formata.Backplane.Schema.validate/3`) and returns
  the transformed data. Modifiers wrap types, and each field is processed from
  the outermost modifier inwards:

    1. `{type, {:default, value}}` replaces an absent or `nil` value with
       `value`; the default is then processed by `type` like any input;
    2. `{:coerce, ...}` converts the source representation (for example
       `"42"` to `42`) and passes values that already have the target type;
    3. the type, its constraints, `{:custom, ...}` validators and nested
       schemas are checked on the (possibly defaulted/coerced) value;
    4. `{type, {:transform, fun}}` maps the validated value. Transforms only
       run for present, non-`nil` values, so write
       `{{type, {:transform, fun}}, {:default, value}}` to transform a default.

  A default can never satisfy `{:required, ...}`: `Formata.Backplane.Schema` rejects
  that combination when the schema is compiled.

  Unknown fields are then handled by the `:unknown` option. With `:strip` (the
  default) the result contains only declared fields, keyed by the schema's keys
  (an atom-keyed schema returns atom keys). With `:allow`, the result keeps the
  input keys: a declared field is written back under the key present in the
  data (an atom schema key matching a string data key keeps the string key),
  undeclared fields are kept unchanged, and a field added by a default uses the
  schema's key.

  Coercion to `:atom!` is rejected (`:unsafe_atom_coercion`) because it would
  create atoms from input data.
  """

  alias Formata.Error
  alias Formata.Schema

  @primitives [
    nil,
    :any,
    :atom,
    :atom!,
    :boolean,
    :list,
    :map,
    :pid,
    :string,
    :integer,
    :float,
    :date,
    :time,
    :datetime,
    :naive_datetime,
    :duration
  ]

  @scalar_with_options [:string, :integer, :float]
  @constraint_ops [:regex, :eq, :neq, :min, :max, :lt, :lte, :gt, :gte, :range, :multiple_of]
  @transforming_ops [:default, :transform, :encode]

  defdelegate merge(schema1, schema2), to: Formata.Backplane.Schema
  defdelegate select(schema, keys), to: Formata.Backplane.Schema
  defdelegate except(schema, keys), to: Formata.Backplane.Schema

  @doc """
  Checks and compiles a native definition.

  Invalid definitions return `:schema` / `:invalid_schema` errors. A definition
  that is valid but outside the pure-validation subset still compiles; the
  limitation is reported when `Formata.validate/3` is called.
  """
  @spec compile(term, keyword) :: {:ok, Schema.t()} | {:error, [Error.t(), ...]}
  def compile(definition, opts \\ []) when is_list(opts) do
    case Formata.Backplane.Schema.validate_schema(definition) do
      {:ok, checked} ->
        {:ok,
         %Schema{
           kind: :native,
           dialect: nil,
           backend: Formata.Backplane.Schema,
           compiled: checked,
           source: definition,
           options: opts,
           plans: plans(checked)
         }}

      {:error, errors} ->
        {:error, schema_errors(errors)}
    end
  end

  defp plans(definition) do
    %{
      pure_allow: plan(definition, %{mode: :pure, reject: false}),
      pure_reject: plan(definition, %{mode: :pure, reject: true}),
      cast: plan(definition, %{mode: :cast, reject: false}),
      cast_reject: plan(definition, %{mode: :cast, reject: true})
    }
  end

  # -- Public operations ----------------------------------------------------------

  @doc false
  @spec validate(Schema.t(), term, keyword) :: :ok | {:error, [Error.t(), ...]}
  def validate(%Schema{kind: :native, plans: plans}, data, opts) do
    with {:ok, unknown} <- unknown_option(opts, :allow, [:allow, :reject]),
         {:ok, definition} <-
           fetch_plan(plans, if(unknown == :reject, do: :pure_reject, else: :pure_allow)) do
      case Formata.Backplane.Schema.validate(definition, data, mode: :permissive) do
        {:ok, _ignored} -> :ok
        {:error, errors} -> {:error, data_errors(errors, data, :validate)}
      end
    end
  end

  @doc false
  @spec cast(Schema.t(), term, keyword) :: {:ok, term} | {:error, [Error.t(), ...]}
  def cast(%Schema{kind: :native, plans: plans}, data, opts) do
    with {:ok, unknown} <- unknown_option(opts, :strip, [:allow, :reject, :strip]),
         {:ok, definition, mode} <- cast_plan(plans, unknown) do
      case Formata.Backplane.Schema.validate(definition, data, mode: mode) do
        {:ok, result} -> {:ok, result}
        {:error, errors} -> {:error, data_errors(errors, data, :cast)}
      end
    end
  end

  defp cast_plan(plans, :strip) do
    with {:ok, definition} <- fetch_plan(plans, :cast), do: {:ok, definition, :strict}
  end

  # With every input field declared, strict mode returns all of them, keyed as
  # declared.
  defp cast_plan(plans, :reject) do
    with {:ok, definition} <- fetch_plan(plans, :cast_reject), do: {:ok, definition, :strict}
  end

  defp cast_plan(plans, :allow) do
    with {:ok, definition} <- fetch_plan(plans, :cast), do: {:ok, definition, :permissive}
  end

  defp fetch_plan(plans, key) do
    case Map.fetch!(plans, key) do
      {:ok, definition} -> {:ok, definition}
      {:error, errors} -> {:error, errors}
    end
  end

  defp unknown_option(opts, default, allowed) do
    value = Keyword.get(opts, :unknown, default)

    if value in allowed do
      {:ok, value}
    else
      Error.error(
        :unsupported,
        :invalid_option,
        "unknown: #{inspect(value)} is not supported here; expected one of #{inspect(allowed)}" <>
          if(value == :strip, do: " (stripping fields is a cast/3 operation)", else: ""),
        backend: __MODULE__,
        details: %{option: :unknown, value: value, allowed: allowed}
      )
    end
  end

  # -- Plans ------------------------------------------------------------------------

  # A plan is the definition actually executed by Formata.Backplane.Schema for one
  # operation. Plans only *add* checks (custom-result guards, unknown-field
  # rules) or replace references with lazily expanded equivalents; they never
  # remove a rule. `{:error, errors}` lists the constructs the operation cannot
  # support.
  defp plan(definition, ctx) do
    ctx = Map.merge(ctx, %{path: [], visiting: MapSet.new(), check_refs: true})

    case walk(definition, ctx) do
      {rewritten, []} -> {:ok, rewritten}
      {_rewritten, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  defp rewrite?(ctx), do: ctx.mode == :pure or ctx.reject

  defp walk(d, _ctx) when d in @primitives, do: {d, []}
  defp walk({:literal, _} = d, _ctx), do: {d, []}

  defp walk({:meta, t, meta}, ctx), do: wrap(walk(t, ctx), &{:meta, &1, meta})
  defp walk({:required, t}, ctx), do: wrap(walk(t, ctx), &{:required, &1})

  defp walk({:required, t, error_opts}, ctx) when is_list(error_opts),
    do: wrap(walk(t, ctx), &{:required, &1, error_opts})

  defp walk({:ref, {mod, name}} = d, ctx) when is_atom(mod) and is_atom(name), do: ref(d, ctx)

  defp walk({:ref, name} = d, ctx) when is_atom(name) do
    {d,
     [
       unsupported(
         ctx,
         :unresolved_ref,
         "{:ref, #{inspect(name)}} has no module; use {:ref, {Module, #{inspect(name)}}} " <>
           "(defschema rewrites local refs automatically)"
       )
     ]}
  end

  defp walk({:multi, field, branches}, ctx) when is_atom(field) and is_map(branches) do
    {branches, errors} =
      Enum.reduce(branches, {%{}, []}, fn {tag, branch}, {acc, errors} ->
        {branch, e} = walk(branch, push(ctx, tag))
        {Map.put(acc, tag, branch), e ++ errors}
      end)

    {{:multi, field, branches}, errors}
  end

  defp walk({type, options}, ctx) when type in @scalar_with_options and is_list(options) do
    errors =
      for {op, _} <- options, op in @transforming_ops, ctx.mode == :pure do
        transforming(ctx, op)
      end

    {{type, options}, errors}
  end

  defp walk({type, {op, _}} = d, _ctx)
       when type in @scalar_with_options and op in @constraint_ops,
       do: {d, []}

  # Formata.Backplane.Schema matches these modifiers before structural forms, so
  # `{:list, {:default, []}}` is a default over `:list`.
  defp walk({t, {op, arg}}, ctx) when op in @transforming_ops do
    {t, errors} = walk(t, ctx)
    errors = if ctx.mode == :pure, do: [transforming(ctx, op) | errors], else: errors
    {{t, {op, arg}}, errors}
  end

  defp walk({:coerce, _} = d, ctx), do: coerce(d, coerce_target(d), ctx)
  defp walk({:coerce, _, _} = d, ctx), do: coerce(d, coerce_target(d), ctx)
  defp walk({:coerce, _, _, _} = d, ctx), do: coerce(d, coerce_target(d), ctx)

  defp walk({:enum, _choices} = d, _ctx), do: {d, []}

  defp walk({:enum, choices, enum_opts}, ctx) when is_list(enum_opts) do
    case Keyword.fetch(enum_opts, :type) do
      {:ok, type} ->
        wrap(walk(type, push(ctx, :type)), &{:enum, choices, Keyword.put(enum_opts, :type, &1)})

      :error ->
        {{:enum, choices, enum_opts}, []}
    end
  end

  defp walk({:list, t}, ctx), do: wrap(walk(t, push(ctx, :list)), &{:list, &1})

  defp walk({:list, t, list_opts}, ctx) when is_list(list_opts),
    do: wrap(walk(t, push(ctx, :list)), &{:list, &1, list_opts})

  defp walk({:map, t}, ctx), do: wrap(walk(t, push(ctx, :map)), &{:map, &1})

  defp walk({:map, k, v}, ctx) do
    {k, e1} = walk(k, push(ctx, :map_key))
    {v, e2} = walk(v, push(ctx, :map))
    {{:map, k, v}, e2 ++ e1}
  end

  defp walk({:tuple, types}, ctx) when is_list(types) do
    {types, errors} = walk_list(types, ctx, :tuple)
    {{:tuple, types}, errors}
  end

  defp walk({:either, {a, b}}, ctx) do
    {a, e1} = walk(a, push(ctx, :either))
    {b, e2} = walk(b, push(ctx, :either))
    {{:either, {a, b}}, e2 ++ e1}
  end

  defp walk({:oneof, types}, ctx) when is_list(types) do
    {types, errors} = walk_list(types, ctx, :oneof)
    {{:oneof, types}, errors}
  end

  defp walk({:schema, s, {:additional_keys, v}}, ctx) do
    # The schema itself declares how undeclared keys are handled.
    {s, e1} = walk_fields(s, push(ctx, :schema))
    {v, e2} = walk(v, push(ctx, :additional_keys))
    {{:schema, s, {:additional_keys, v}}, e2 ++ e1}
  end

  defp walk({:schema, s}, ctx), do: wrap(walk(s, push(ctx, :schema)), &{:schema, &1})

  defp walk({:schema, s, schema_opts}, ctx) when is_list(schema_opts),
    do: wrap(walk(s, push(ctx, :schema)), &{:schema, &1, schema_opts})

  defp walk({:cond, condition, a, b}, ctx) do
    {a, e1} = walk(a, push(ctx, :cond))
    {b, e2} = walk(b, push(ctx, :cond))
    {{:cond, condition, a, b}, e2 ++ e1}
  end

  defp walk({:dependent, field, condition, type}, ctx) when is_atom(field) do
    wrap(walk(type, push(ctx, :dependent)), &{:dependent, field, condition, &1})
  end

  defp walk({:dependent, _callback} = d, ctx) do
    if rewrite?(ctx) do
      operation = if ctx.mode == :pure, do: "pure validation", else: "unknown: :reject"

      {d,
       [
         unsupported(
           ctx,
           error_code(ctx),
           "{:dependent, callback} computes its schema at run time, so #{operation} " <>
             "cannot check it; use {:dependent, field, check, type} or cast/3"
         )
       ]}
    else
      {d, []}
    end
  end

  defp walk({:custom, validator} = d, ctx) do
    if ctx.mode == :pure, do: {{:custom, guard_custom(validator)}, []}, else: {d, []}
  end

  defp walk(map, ctx) when is_map(map) and not is_struct(map) do
    {fields, errors} = walk_fields(map, ctx)

    if ctx.reject do
      declared = Map.keys(fields)
      {{:schema, fields, {:additional_keys, {:custom, reject_unknown(declared)}}}, errors}
    else
      {fields, errors}
    end
  end

  defp walk(keyword, ctx) when is_list(keyword) do
    {fields, errors} = walk_fields(keyword, ctx)

    errors =
      if ctx.reject do
        [
          unsupported(
            ctx,
            :unknown_reject_unsupported,
            "unknown: :reject is not supported for keyword list schemas; use a map schema"
          )
          | errors
        ]
      else
        errors
      end

    {fields, errors}
  end

  defp walk(other, ctx) do
    if ctx.mode == :pure do
      {other,
       [
         unsupported(
           ctx,
           :pure_validation_unsupported,
           "#{inspect(other, limit: 5)} is not part of the pure-validation subset"
         )
       ]}
    else
      {other, []}
    end
  end

  defp walk_fields(map, ctx) when is_map(map) do
    Enum.reduce(map, {%{}, []}, fn {key, t}, {acc, errors} ->
      {t, e} = walk(t, push(ctx, key))
      {Map.put(acc, key, t), e ++ errors}
    end)
  end

  defp walk_fields(keyword, ctx) when is_list(keyword) do
    {fields, errors} =
      Enum.reduce(keyword, {[], []}, fn {key, t}, {acc, errors} ->
        {t, e} = walk(t, push(ctx, key))
        {[{key, t} | acc], e ++ errors}
      end)

    {Enum.reverse(fields), errors}
  end

  defp walk_fields(other, ctx), do: walk(other, ctx)

  defp walk_list(types, ctx, segment) do
    {types, errors} =
      types
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {t, i}, {acc, errors} ->
        {t, e} = walk(t, push(push(ctx, segment), i))
        {[t | acc], e ++ errors}
      end)

    {Enum.reverse(types), errors}
  end

  defp wrap({t, errors}, fun), do: {fun.(t), errors}

  defp push(ctx, segment), do: %{ctx | path: ctx.path ++ [segment]}

  defp error_code(%{mode: :pure}), do: :pure_validation_unsupported
  defp error_code(_ctx), do: :unknown_reject_unsupported

  defp transforming(ctx, op) do
    unsupported(
      ctx,
      :pure_validation_unsupported,
      "#{inspect(op)} transforms data, so it cannot run in pure validation; use Formata.cast/3"
    )
  end

  defp coerce(d, target, ctx) do
    errors =
      if contains?(target, :atom!) do
        [
          unsupported(
            ctx,
            :unsafe_atom_coercion,
            "coercion to :atom! creates atoms from input data and is not supported"
          )
        ]
      else
        []
      end

    errors =
      if ctx.mode == :pure,
        do: [
          unsupported(
            ctx,
            :pure_validation_unsupported,
            "{:coerce, ...} converts data, so it cannot run in pure validation; use Formata.cast/3"
          )
          | errors
        ],
        else: errors

    # Coercion targets are plain types; nothing inside needs rewriting.
    {d, errors}
  end

  defp coerce_target({:coerce, target}), do: target
  defp coerce_target({:coerce, target, opts}) when is_list(opts), do: target
  defp coerce_target({:coerce, _source, target}), do: target
  defp coerce_target({:coerce, _source, target, _opts}), do: target

  defp contains?(term, atom) when is_atom(term), do: term == atom
  defp contains?(term, atom) when is_tuple(term), do: term |> Tuple.to_list() |> contains?(atom)
  defp contains?(term, atom) when is_list(term), do: Enum.any?(term, &contains?(&1, atom))

  defp contains?(term, atom) when is_map(term) and not is_struct(term),
    do: Enum.any?(term, fn {_k, v} -> contains?(v, atom) end)

  defp contains?(_term, _atom), do: false

  defp unsupported(ctx, code, message) do
    Error.new(:unsupported, code, message,
      backend: __MODULE__,
      schema_path: ctx.path,
      details: %{operation: if(ctx.mode == :pure, do: :validate, else: :cast)}
    )
  end

  # -- References ---------------------------------------------------------------------

  # When the plan rewrites the definition, a reference becomes a dependent
  # schema that expands (and rewrites) its target lazily, which keeps
  # recursive definitions finite. Every reachable target is checked once at
  # compile time.
  defp ref({:ref, {mod, name}} = d, ctx) do
    key = {mod, name}

    errors =
      cond do
        not ctx.check_refs or MapSet.member?(ctx.visiting, key) ->
          []

        true ->
          case fetch_ref(mod, name) do
            {:ok, target} ->
              ctx = %{ctx | visiting: MapSet.put(ctx.visiting, key), path: ctx.path ++ [d]}
              {_rewritten, errors} = walk(target, ctx)
              errors

            {:error, message} ->
              [
                Error.new(:schema, :unresolved_ref, message,
                  backend: Formata.Backplane.Schema,
                  schema_path: ctx.path
                )
              ]
          end
      end

    if rewrite?(ctx) do
      lazy_ctx = %{ctx | check_refs: false}

      expand = fn _current, _root ->
        case fetch_ref(mod, name) do
          {:ok, target} -> {:ok, elem(walk(target, lazy_ctx), 0)}
          {:error, message} -> {:error, message, ref: inspect(key)}
        end
      end

      {{:dependent, expand}, errors}
    else
      {d, errors}
    end
  end

  defp fetch_ref(mod, name) do
    cond do
      not Code.ensure_loaded?(mod) ->
        {:error, "module #{inspect(mod)} is not available for ref #{inspect(name)}"}

      not function_exported?(mod, :get_schema, 1) ->
        {:error, "#{inspect(mod)} does not export get_schema/1 for ref #{inspect(name)}"}

      true ->
        try do
          {:ok, mod.get_schema(name)}
        rescue
          FunctionClauseError ->
            {:error, "ref #{inspect(name)} is not defined in #{inspect(mod)}"}
        end
    end
  end

  # -- Guards added by plans ------------------------------------------------------------

  defp guard_custom(validator) do
    fn value, root ->
      result = call_custom(validator, value, root)

      case result do
        :ok ->
          :ok

        {:error, template, info} when is_binary(template) and (is_list(info) or is_map(info)) ->
          result

        {:error, errors} when is_list(errors) ->
          result

        %Formata.Backplane.Schema.Error{} ->
          result

        other ->
          {:error,
           "custom validator returned %{actual}; pure validation requires :ok or an error",
           [actual: inspect(other, limit: 5), formata_non_pure_custom: true]}
      end
    end
  end

  # Mirrors Formata.Backplane.Schema's dispatch for each custom validator form.
  defp call_custom(fun, value, _root) when is_function(fun, 1), do: fun.(value)
  defp call_custom(fun, value, root) when is_function(fun, 2), do: fun.(value, root)

  defp call_custom({mod, fun}, value, root) when is_atom(mod) and is_atom(fun) do
    Code.ensure_loaded(mod)

    cond do
      function_exported?(mod, fun, 1) -> apply(mod, fun, [value])
      function_exported?(mod, fun, 2) -> apply(mod, fun, [value, root])
      true -> {:error, "expected %{mod} to export %{fun}/1 or %{fun}/2", mod: mod, fun: fun}
    end
  end

  defp call_custom({mod, fun, args}, value, root)
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    Code.ensure_loaded(mod)
    arity = length(args)

    cond do
      function_exported?(mod, fun, arity + 1) ->
        apply(mod, fun, [value | args])

      function_exported?(mod, fun, arity + 2) ->
        apply(mod, fun, [value, root | args])

      true ->
        {:error, "expected %{mod} to export %{fun} with arity %{base} or %{arity}",
         mod: mod, fun: fun, base: arity + 1, arity: arity + 2}
    end
  end

  defp reject_unknown(declared) do
    fn _value ->
      {:error, "is not declared by the schema", [formata_unknown_fields: declared]}
    end
  end

  # -- Error conversion ------------------------------------------------------------------------

  defp schema_errors(errors) do
    errors
    |> List.wrap()
    |> leaves()
    |> Enum.map(fn error ->
      Error.new(:schema, :invalid_schema, error.message || "invalid schema definition",
        backend: Formata.Backplane.Schema,
        schema_path: error.path || [],
        details: clean_content(error.content),
        cause: error
      )
    end)
  end

  defp data_errors(errors, data, operation) do
    errors
    |> List.wrap()
    |> leaves()
    |> Enum.flat_map(&data_error(&1, data, operation))
  end

  defp data_error(error, data, operation) do
    content = content_map(error.content)
    {path, value} = resolve_path(data, error.path || [])

    cond do
      Map.has_key?(content, :formata_unknown_fields) ->
        unknown_field_errors(value, content.formata_unknown_fields, path, error)

      Map.has_key?(content, :formata_non_pure_custom) ->
        [
          Error.new(:unsupported, :non_pure_custom, error.message,
            backend: Formata.Backplane.Schema,
            path: path,
            details: clean_content(content),
            cause: error
          )
        ]

      true ->
        code = error.code || :invalid
        kind = if operation == :cast and code == :coercion, do: :transform, else: :validation

        [
          Error.new(kind, code, error.message || "is invalid",
            backend: Formata.Backplane.Schema,
            path: path,
            details: clean_content(content),
            cause: error
          )
        ]
    end
  end

  defp unknown_field_errors(value, declared, path, cause) do
    declared = MapSet.new(declared, &to_string/1)

    keys =
      if is_map(value),
        do: value |> Map.keys() |> Enum.reject(&MapSet.member?(declared, to_string(&1))),
        else: []

    case Enum.sort(keys) do
      [] ->
        [unknown_field(path, nil, cause)]

      keys ->
        Enum.map(keys, &unknown_field(path ++ [&1], &1, cause))
    end
  end

  defp unknown_field(path, key, cause) do
    message =
      if key, do: "field #{inspect(key)} is not declared by the schema", else: cause.message

    Error.new(:validation, :unknown_field, message,
      backend: Formata.Backplane.Schema,
      path: path,
      details: %{key: key},
      cause: cause
    )
  end

  defp leaves(errors) do
    Enum.flat_map(errors, fn
      %Formata.Backplane.Schema.Error{errors: [_ | _] = nested} -> leaves(nested)
      %Formata.Backplane.Schema.Error{} = error -> [error]
      # Scalar roots can return bare `{:error, template, info}` tuples.
      {:error, template, info} -> [Formata.Backplane.Schema.Error.new_single(template, info)]
      {:error, nested} when is_list(nested) -> leaves(nested)
    end)
  end

  defp content_map(content) when is_map(content), do: content
  defp content_map(content) when is_list(content), do: Map.new(content)
  defp content_map(_), do: %{}

  defp clean_content(content) do
    content
    |> content_map()
    |> Map.drop([:formata_unknown_fields, :formata_non_pure_custom, :schema])
  end

  # Native error paths use schema keys (atoms); report the key actually present
  # in the data instead. A key that is absent from the data is reported in the
  # data's key style: as a string unless the enclosing map uses atom keys.
  defp resolve_path(data, path), do: resolve_path(data, path, [], string_keys_style?(data))

  defp resolve_path(data, [], acc, _strings?), do: {Enum.reverse(acc), data}

  defp resolve_path(data, [segment | rest], acc, strings?) when is_map(data) do
    strings? = if map_size(data) == 0, do: strings?, else: string_keys_style?(data)

    cond do
      Map.has_key?(data, segment) ->
        resolve_path(Map.get(data, segment), rest, [segment | acc], strings?)

      is_atom(segment) and Map.has_key?(data, Atom.to_string(segment)) ->
        key = Atom.to_string(segment)
        resolve_path(Map.get(data, key), rest, [key | acc], strings?)

      true ->
        resolve_path(nil, rest, [absent_key(segment, strings?) | acc], strings?)
    end
  end

  defp resolve_path(data, [segment | rest], acc, strings?)
       when is_list(data) and is_integer(segment),
       do: resolve_path(Enum.at(data, segment), rest, [segment | acc], strings?)

  defp resolve_path(data, [segment | rest], acc, _strings?)
       when is_list(data) and is_atom(segment),
       do: resolve_path(Keyword.get(data, segment), rest, [segment | acc], false)

  defp resolve_path(_data, [segment | rest], acc, strings?),
    do: resolve_path(nil, rest, [absent_key(segment, strings?) | acc], strings?)

  defp absent_key(segment, true)
       when is_atom(segment) and not is_nil(segment) and not is_boolean(segment),
       do: Atom.to_string(segment)

  defp absent_key(segment, _strings?), do: segment

  defp string_keys_style?(map) when is_map(map) and not is_struct(map),
    do: not Enum.any?(Map.keys(map), &is_atom/1)

  defp string_keys_style?(_), do: true
end
