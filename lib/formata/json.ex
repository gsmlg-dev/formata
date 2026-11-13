defmodule Formata.JSON do
  @moduledoc """
  A JSON library module for Phoenix and Plug.

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

  `decode!/1` uses Formata's strict JSON decoder (`Formata.decode/3` with
  `:json`): RFC 8259, string keys (never atoms), and duplicate object keys
  rejected instead of silently keeping one value, so a request body or socket
  message cannot carry two different values for one field. Invalid input
  raises the first `Formata.Error` (an exception), which `Plug.Parsers` turns
  into a `Plug.Parsers.ParseError` (HTTP 400).

  `decode!/2` takes the `:json` decode options, for example
  `json_decoder: {Formata.JSON, :decode!, [[comments: true]]}`.

  ## Encoding

  `encode!/1` and `encode_to_iodata!/1` delegate to Elixir's built-in `JSON`,
  so they accept what Phoenix and LiveView send: atom keys and values,
  integer keys, `Date`/`Time`/`DateTime` values, and structs that implement
  the `JSON.Encoder` protocol (`@derive JSON.Encoder`). This differs from
  `Formata.encode(data, :json)`, which accepts only the strict portable value
  domain; use that for documents that other formats or schemas must agree
  with.
  """

  @doc """
  Decodes JSON strictly, raising `Formata.Error` on invalid input.

      iex> Formata.JSON.decode!(~s({"a": [1, 2.5, null]}))
      %{"a" => [1, 2.5, nil]}

      iex> Formata.JSON.decode!(~s({"a": 1, "a": 2}))
      ** (Formata.Error) duplicate object key "a"
  """
  @spec decode!(binary, keyword) :: term
  def decode!(input, opts \\ []) when is_binary(input) and is_list(opts) do
    case Formata.decode(input, :json, opts) do
      {:ok, data} -> data
      {:error, [error | _]} -> raise error
    end
  end

  @doc """
  Encodes a term as a JSON binary with Elixir's `JSON`.

      iex> Formata.JSON.encode!(%{status: :ok})
      ~s({"status":"ok"})
  """
  @spec encode!(term) :: binary
  def encode!(term), do: Elixir.JSON.encode!(term)

  @doc """
  Encodes a term as JSON iodata with Elixir's `JSON`.

      iex> Formata.JSON.encode_to_iodata!([1, "a"]) |> IO.iodata_to_binary()
      ~s([1,"a"])
  """
  @spec encode_to_iodata!(term) :: iodata
  def encode_to_iodata!(term), do: Elixir.JSON.encode_to_iodata!(term)
end
