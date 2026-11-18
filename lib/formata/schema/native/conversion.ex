defmodule Formata.Schema.Native.Conversion do
  @moduledoc false
  alias Formata.{Error, Schema}
  alias Formata.NativeSchema.JSONSchema.{Encoder, Decoder}

  @annotations ~w($schema $comment title description default examples deprecated readOnly writeOnly)
  @constraints %{
    "string" => ~w(minLength maxLength pattern),
    "integer" => ~w(minimum maximum exclusiveMinimum exclusiveMaximum multipleOf),
    "number" => ~w(minimum maximum exclusiveMinimum exclusiveMaximum multipleOf),
    "array" => ~w(items minItems maxItems uniqueItems),
    "object" => ~w(properties required additionalProperties),
    "boolean" => [],
    "null" => []
  }

  def export(definition, opts) do
    specs = [
      {:exclude_meta_keys, fn v -> is_list(v) and Enum.all?(v, &is_atom/1) end,
       "a list of annotation atoms"},
      {:on_unsupported, &(&1 in [:error, :omit]), ":error or :omit"}
    ]

    with :ok <- options(opts, specs),
         {:ok, _} <- Schema.native(definition) do
      try do
        Formata.NativeSchema.walk(definition, &export_node/1)

        json =
          Encoder.encode(
            definition,
            Keyword.put(
              opts,
              :on_unsupported,
              if(opts[:on_unsupported] == :omit, do: :omit, else: :raise)
            ) ++ [union_keyword: "anyOf"]
          )

        {:ok, json |> Formata.JSON.encode!() |> Formata.JSON.decode!()}
      rescue
        error in Encoder.UnsupportedTypeError ->
          unsupported([], Exception.message(error))

        error in [Protocol.UndefinedError, ArgumentError, Formata.Error] ->
          Error.error(:schema, :invalid_schema, Exception.message(error),
            backend: __MODULE__,
            cause: error
          )
      catch
        {:conversion, path, message} -> unsupported(path, message)
      end
    end
  end

  defp export_node({:ref, _}), do: reject([], "reference export is not supported")

  defp export_node({:map, key, _}) when key != :string,
    do: reject([], "constrained map keys cannot be exported")

  defp export_node({:schema, _, opts}) when is_list(opts) and opts != [],
    do: reject([], "schema option lists cannot be exported")

  defp export_node(node) when is_map(node) and not is_struct(node) do
    keys = Map.keys(node)

    if not Enum.all?(keys, &(is_atom(&1) or is_binary(&1))) or
         length(Enum.uniq_by(keys, &to_string/1)) != length(keys),
       do: reject([], "object keys must have distinct JSON string representations")

    {:cont, node}
  end

  defp export_node(node), do: {:cont, node}

  def import_schema(document, opts) do
    with :ok <- options(opts, [{:keys, &(&1 == :strings), ":strings"}]),
         {:ok, _} <- Schema.json_schema(document, dialect: :draft7),
         :ok <- check_meta(document) do
      try do
        check_import(document, [])

        case Decoder.decode(document, keys: :strings) do
          {:ok, definition} ->
            {:ok, definition}

          {:error, reason} ->
            Error.error(:schema, :invalid_schema, "native import failed",
              backend: __MODULE__,
              cause: reason
            )
        end
      catch
        {:conversion, path, message} -> unsupported(path, message)
      end
    end
  end

  defp check_meta(document) do
    {:ok, meta} =
      Formata.JSONSchema.Draft7.Schemas.fetch("http://json-schema.org/draft-07/schema#")

    {:ok, compiled} = Schema.json_schema(meta, dialect: :draft7, format_assertion: true)

    case Formata.validate(document, compiled) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error,
         Enum.map(
           errors,
           &%{&1 | kind: :schema, code: :invalid_schema, schema_path: &1.path, path: []}
         )}
    end
  end

  defp check_import(schema, path) when is_map(schema) do
    assertions = Map.keys(schema) -- @annotations
    type = Map.get(schema, "type")

    allowed =
      cond do
        is_binary(type) -> ["type", "enum"] ++ Map.get(@constraints, type, [])
        is_list(type) -> ["type"]
        Map.has_key?(schema, "enum") -> ["enum"]
        Map.has_key?(schema, "const") -> ["const"]
        Map.has_key?(schema, "anyOf") -> ["anyOf"]
        true -> []
      end

    for key <- assertions -- allowed,
        do: reject(path ++ [key], "unsupported import keyword or combination: #{key}")

    if Map.has_key?(schema, "enum") and assertions -- ["enum", "type"] != [],
      do: reject(path, "enum combined with other assertions is not supported")

    if type in ["object", "array"] and Map.has_key?(schema, "enum"),
      do: reject(path ++ ["enum"], "object/array typed enums are not supported")

    if is_list(type) do
      for item <- type, do: check_import(%{"type" => item}, path ++ ["type"])
    end

    if is_map(schema["properties"]) do
      for {key, child} <- schema["properties"],
          do: check_import(child, path ++ ["properties", key])
    end

    if type == "object" do
      if Map.get(schema, "additionalProperties") == false,
        do:
          reject(
            path ++ ["additionalProperties"],
            "closed objects are not supported by native import"
          )

      if Map.get(schema, "required", []) -- Map.keys(Map.get(schema, "properties", %{})) != [],
        do: reject(path ++ ["required"], "required names must be declared in properties")

      if is_map(schema["additionalProperties"]),
        do: check_import(schema["additionalProperties"], path ++ ["additionalProperties"])
    end

    if Map.has_key?(schema, "items"), do: check_import(schema["items"], path ++ ["items"])

    if Map.has_key?(schema, "anyOf") do
      for {child, index} <- Enum.with_index(schema["anyOf"]),
          do: check_import(child, path ++ ["anyOf", index])
    end

    :ok
  end

  defp check_import(_schema, path),
    do: reject(path, "only object schemas are supported by native import")

  defp options(opts, specs), do: Formata.Codec.check_options(opts, specs, backend: __MODULE__)
  defp reject(path, message), do: throw({:conversion, path, message})

  defp unsupported(path, message),
    do:
      Error.error(:unsupported, :conversion_unsupported, message,
        backend: __MODULE__,
        schema_path: path
      )
end
