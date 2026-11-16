defmodule Formata.Codec do
  @moduledoc """
  Behaviour for format adapters and the portable value domain they share.

  Built-in codecs:

  | Format  | Module                | Decoder          | Encoder                     |
  | ------- | --------------------- | ---------------- | --------------------------- |
  | `:json` | `Formata.Codec.JSON`  | `Formata.JSON.Backend`          | `Formata.JSON.Backend`                     |
  | `:json5` | `Formata.Codec.JSON5` | `Formata.Codec.JSON5` (native) | `Formata.Codec.JSON5` (native) |
  | `:toml` | `Formata.Codec.TOML`  | `Formata.TOML` (gsmlg_toml) | `Formata.Codec.TOML.Encoder` |
  | `:yaml` | `Formata.Codec.YAML`  | `Formata.YAML.Reader`     | `Formata.YAML.Writer`                      |

  A custom codec is any module implementing this behaviour; pass the module
  wherever a format atom is accepted.

  ## Portable value domain

  Decoders return ordinary Elixir terms:

  | Value                 | Elixir representation                                  |
  | --------------------- | ------------------------------------------------------ |
  | null                  | `nil`                                                  |
  | boolean               | `true` / `false`                                       |
  | integer               | integer                                                |
  | float                 | float                                                  |
  | +infinity / -infinity / NaN | `:infinity` / `:negative_infinity` / `:nan`      |
  | string                | UTF-8 binary                                           |
  | array / sequence      | list                                                   |
  | object / table / mapping | map with string keys                                |
  | local date / local time | `Date` / `Time`                                      |
  | local date-time       | `NaiveDateTime`                                        |
  | offset date-time      | `DateTime`                                             |

  Keys from documents stay strings; Formata never creates atoms from document
  content. A field that is absent is absent from the map; an explicit null is
  present with the value `nil`.

  Each encoder accepts only the subset its format can represent and rejects
  everything else with an `:encode` error (`:unrepresentable`, `:invalid_key`,
  `:invalid_root`, `:out_of_range`). Nothing is dropped, stringified, or
  rounded implicitly; use `Formata.Transform` for explicit conversions.
  """

  alias Formata.Error

  @type format :: :json | :json5 | :toml | :yaml | module
  @type result(t) :: {:ok, t} | {:error, [Error.t(), ...]}

  @doc "Returns the format name used in errors."
  @callback format() :: atom

  @doc "Decodes a complete document."
  @callback decode(input :: binary, opts :: keyword) :: result(term)

  @doc "Encodes a term as a complete document."
  @callback encode(data :: term, opts :: keyword) :: result(binary)

  @builtin %{
    json: Formata.Codec.JSON,
    json5: Formata.Codec.JSON5,
    toml: Formata.Codec.TOML,
    yaml: Formata.Codec.YAML
  }

  @doc """
  Resolves a format atom or codec module to a codec module.

      iex> Formata.Codec.fetch(:json)
      {:ok, Formata.Codec.JSON}

      iex> {:error, [%Formata.Error{kind: :unsupported, code: :unknown_format}]} = Formata.Codec.fetch(:xml)
  """
  @spec fetch(format) :: {:ok, module} | {:error, [Error.t(), ...]}
  def fetch(format) when is_map_key(@builtin, format), do: {:ok, Map.fetch!(@builtin, format)}

  def fetch(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :decode, 2) and
         function_exported?(module, :encode, 2) and function_exported?(module, :format, 0) do
      {:ok, module}
    else
      Error.error(
        :unsupported,
        :unknown_format,
        "unknown format #{inspect(module)}; expected :json, :json5, :toml, :yaml, or a Formata.Codec module",
        details: %{format: module, supported: Map.keys(@builtin)}
      )
    end
  end

  @doc "The built-in format names."
  @spec formats() :: [atom]
  def formats, do: Map.keys(@builtin)

  # -- Shared value-domain checking -------------------------------------------

  @typedoc false
  @type profile :: %{
          required(:format) => atom,
          required(:backend) => module,
          required(:null) => boolean,
          required(:special_floats) => boolean,
          required(:temporal) => boolean,
          required(:key?) => (term -> boolean),
          required(:key_hint) => String.t(),
          optional(:int_range) => {integer, integer} | nil
        }

  @doc false
  # Walks `data` and returns every value outside the profile's domain.
  @spec check_domain(term, profile) :: :ok | {:error, [Error.t(), ...]}
  def check_domain(data, profile) do
    case walk(data, [], profile, []) do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defguardp is_special_float(v) when v in [:infinity, :negative_infinity, :nan]

  defp walk(nil, path, %{null: false} = p, acc),
    do: [unrepresentable(p, path, nil, "null values cannot be represented") | acc]

  defp walk(v, _path, _p, acc) when is_nil(v) or is_boolean(v), do: acc

  defp walk(v, path, p, acc) when is_integer(v) do
    case Map.get(p, :int_range) do
      {min, max} when v < min or v > max ->
        error =
          Error.new(:encode, :out_of_range, "integer #{v} is outside the representable range",
            backend: p.backend,
            format: p.format,
            path: Enum.reverse(path),
            details: %{value: v, min: min, max: max}
          )

        [error | acc]

      _ ->
        acc
    end
  end

  defp walk(v, _path, _p, acc) when is_float(v), do: acc
  defp walk(v, _path, %{special_floats: true}, acc) when is_special_float(v), do: acc

  defp walk(v, path, p, acc) when is_special_float(v),
    do: [
      unrepresentable(p, path, v, "#{inspect(v)} (non-finite number) cannot be represented") | acc
    ]

  defp walk(v, path, p, acc) when is_binary(v) do
    if String.valid?(v),
      do: acc,
      else: [unrepresentable(p, path, v, "binary is not valid UTF-8 text") | acc]
  end

  defp walk(%struct{} = v, path, p, acc) when struct in [Date, Time, NaiveDateTime, DateTime] do
    if p.temporal,
      do: acc,
      else: [
        unrepresentable(
          p,
          path,
          v,
          "#{inspect(struct)} values cannot be represented; convert them explicitly, " <>
            "for example with Formata.Transform.temporal_to_iso8601/1"
        )
        | acc
      ]
  end

  defp walk(%struct{} = v, path, p, acc),
    do: [unrepresentable(p, path, v, "struct #{inspect(struct)} cannot be represented") | acc]

  defp walk(v, path, p, acc) when is_list(v) do
    v
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {item, i}, acc -> walk(item, [i | path], p, acc) end)
  end

  defp walk(v, path, p, acc) when is_map(v) do
    v
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.reduce(acc, fn {k, item}, acc ->
      message =
        cond do
          is_binary(k) and not String.valid?(k) ->
            "key #{inspect(k)} is not valid UTF-8 text"

          not p.key?.(k) ->
            "key #{inspect(k)} is not allowed: #{p.key_hint}"

          true ->
            nil
        end

      acc =
        if message do
          error =
            Error.new(:encode, :invalid_key, message,
              backend: p.backend,
              format: p.format,
              path: Enum.reverse(path),
              details: %{key: k}
            )

          [error | acc]
        else
          acc
        end

      walk(item, [k | path], p, acc)
    end)
  end

  defp walk(v, path, p, acc),
    do: [unrepresentable(p, path, v, "#{inspect(v)} cannot be represented") | acc]

  defp unrepresentable(p, path, value, message) do
    Error.new(:encode, :unrepresentable, message,
      backend: p.backend,
      format: p.format,
      path: Enum.reverse(path),
      details: %{value: value}
    )
  end

  @doc false
  # Checks codec options against `specs`, a list of
  # `{name, valid?, expected_description}`. Unknown options and invalid values
  # are `:unsupported` / `:invalid_option` errors; every problem is reported.
  @spec check_options(term, [{atom, (term -> boolean), String.t()}], keyword) ::
          :ok | {:error, [Error.t(), ...]}
  def check_options(opts, specs, fields) when is_list(opts) do
    allowed = Enum.map(specs, &elem(&1, 0))

    errors =
      Enum.flat_map(opts, fn
        {name, value} when is_atom(name) ->
          case List.keyfind(specs, name, 0) do
            nil ->
              [
                option_error(
                  "unknown option #{inspect(name)}; supported options: #{inspect(allowed)}",
                  name,
                  value,
                  allowed,
                  fields
                )
              ]

            {^name, valid?, expected} ->
              if valid?.(value),
                do: [],
                else: [
                  option_error(
                    "invalid value #{inspect(value)} for option #{inspect(name)}; expected #{expected}",
                    name,
                    value,
                    allowed,
                    fields
                  )
                ]
          end

        other ->
          [
            option_error(
              "options must be a keyword list, got element #{inspect(other)}",
              nil,
              other,
              allowed,
              fields
            )
          ]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp option_error(message, name, value, allowed, fields) do
    Error.new(
      :unsupported,
      :invalid_option,
      message,
      Keyword.put(fields, :details, %{option: name, value: value, allowed: allowed})
    )
  end

  @doc false
  # Computes 1-based line/column for a byte offset reported by a backend.
  @spec offset_location(binary, non_neg_integer) :: map
  def offset_location(input, offset) when is_binary(input) and is_integer(offset) do
    prefix = binary_part(input, 0, min(offset, byte_size(input)))
    lines = :binary.split(prefix, "\n", [:global])
    last = List.last(lines)
    column = if String.valid?(last), do: String.length(last) + 1, else: byte_size(last) + 1
    %{offset: offset, line: length(lines), column: column}
  end
end
