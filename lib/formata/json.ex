defmodule Formata.JSON do
  @moduledoc """
  JSON for Elixir applications, Phoenix, and Plug.

      # config/config.exs
      config :phoenix, :json_library, Formata.JSON

      # endpoint.ex
      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        json_decoder: Phoenix.json_library()

  It provides the functions Phoenix requires of a `:json_library` (the
  raising, single-argument functions of Elixir's built-in `JSON`):
  `decode!/1`, `encode!/1`, and `encode_to_iodata!/1`.

  ## Decoding

  `decode/2` and `decode!/2` use Formata's strict JSON decoder:
  RFC 8259, string keys (never atoms), and duplicate object keys
  rejected instead of silently keeping one value, so a request body or socket
  message cannot carry two different values for one field. On invalid input,
  `decode!/2` raises the first `Formata.Error` (an exception), which
  `Plug.Parsers` turns into a `Plug.Parsers.ParseError` (HTTP 400).

  Options:

    * `:comments` and `:trailing_commas` - the boolean `:json` decode options,
      both `false` by default. For example,
      `json_decoder: {Formata.JSON, :decode!, [[comments: true]]}`.
    * `:floats` - `:native` (default), or a one-argument function receiving the
      original fractional/exponent number token. For exact Decimal values use
      `floats: &Decimal.new/1` with your application's Decimal dependency. No
      binary float conversion occurs; integers remain integers. Callback
      return values are used directly and callback exceptions propagate.
    * `:objects` - `:maps` (default) or `:ordered_objects`, which returns
      `Formata.JSON.OrderedObject` at every object, including nested objects.
      Duplicate keys remain errors in both modes.

  Unknown options, invalid values, and malformed keyword entries return
  `:unsupported` / `:invalid_option` errors. `floats: :decimals` is not an
  option; pass the conversion function instead. `decode/2` returns
  `{:ok, data}` or `{:error, [Formata.Error.t()]}`; `decode!/2` raises the first
  error. Syntax errors carry source locations; duplicate-key errors carry
  the containing object's path and the key in `details`.

  ## Encoding

  `encode!/2` and `encode_to_iodata!/2` delegate to Elixir's built-in `JSON`,
  so they accept what Phoenix and LiveView send: atom keys and values,
  integer keys, `Date`/`Time`/`DateTime` values, and structs that implement
  the `JSON.Encoder` protocol (`@derive JSON.Encoder`). This differs from
  `Formata.encode(data, :json)`, which accepts only the strict portable value
  domain; use that for documents that other formats or schemas must agree
  with.

  Both accept `pretty: true` for two-space indentation (default `false`),
  including ordered objects nested in ordinary Elixir values. Invalid
  options raise `Formata.Error`; unsupported values retain Elixir JSON's
  encoding exceptions. The portable `Formata.encode/3` and `Formata.decode/3`
  retain their strict value domain and options.
  """

  @doc """
  Decodes JSON, returning data or structured errors. See the module options.

      iex> Formata.JSON.decode(~s({"a": 1}))
      {:ok, %{"a" => 1}}
  """
  @spec decode(binary, keyword) :: Formata.Codec.result(term)
  def decode(input, opts \\ []) when is_binary(input) and is_list(opts) do
    specs = [
      {:comments, &is_boolean/1, "a boolean"},
      {:trailing_commas, &is_boolean/1, "a boolean"},
      {:floats, fn value -> value == :native or is_function(value, 1) end,
       ":native or a one-argument function (for example, &Decimal.new/1)"},
      {:objects, &(&1 in [:maps, :ordered_objects]), ":maps or :ordered_objects"}
    ]

    with :ok <- Formata.Codec.check_options(opts, specs, backend: __MODULE__, format: :json) do
      Formata.JSON.Decoder.decode(input, opts)
    end
  end

  @doc """
  Decodes JSON strictly, raising `Formata.Error` on invalid input.

      iex> Formata.JSON.decode!(~s({"a": [1, 2.5, null]}))
      %{"a" => [1, 2.5, nil]}

      iex> Formata.JSON.decode!(~s({"a": 1, "a": 2}))
      ** (Formata.Error) duplicate object key "a"
  """
  @spec decode!(binary, keyword) :: term
  def decode!(input, opts \\ []) when is_binary(input) and is_list(opts) do
    case decode(input, opts) do
      {:ok, data} -> data
      {:error, [error | _]} -> raise error
    end
  end

  @doc """
  Encodes a term as a JSON binary with Elixir's `JSON`.

      iex> Formata.JSON.encode!(%{status: :ok})
      ~s({"status":"ok"})
  """
  @spec encode!(term, keyword) :: binary
  def encode!(term, opts \\ []) do
    term |> encode_to_iodata!(opts) |> IO.iodata_to_binary()
  end

  @doc """
  Encodes a term as JSON iodata with Elixir's `JSON`.

      iex> Formata.JSON.encode_to_iodata!([1, "a"]) |> IO.iodata_to_binary()
      ~s([1,"a"])
  """
  @spec encode_to_iodata!(term, keyword) :: iodata
  def encode_to_iodata!(term, opts \\ []) when is_list(opts) do
    case Formata.Codec.check_options(opts, [{:pretty, &is_boolean/1, "a boolean"}],
           backend: __MODULE__,
           format: :json
         ) do
      :ok ->
        encoded = Elixir.JSON.encode_to_iodata!(term)

        if Keyword.get(opts, :pretty, false),
          do: Formata.JSON.Backend.Formatter.pretty_print_to_iodata(encoded),
          else: encoded

      {:error, [error | _]} ->
        raise error
    end
  end
end
