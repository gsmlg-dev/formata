defmodule Formata.Codec.TOML do
  @moduledoc """
  TOML codec: decoding with `gsmlg_toml` (`Formata.Toml.decode/2`), encoding with
  `Formata.Codec.TOML.Encoder`.

  ## Decoding

    * The root is always a map (table); keys stay strings.
    * `inf`, `-inf`, `nan` become `:infinity`, `:negative_infinity`, `:nan`.
    * Local date, local time, and local date-time become `Date`, `Time`, and
      `NaiveDateTime`.
    * Offset date-times become UTC `DateTime` values. `gsmlg_toml` converts the
      instant to UTC, so the original offset (for example `-08:00`) is not
      preserved; the instant is.
    * Duplicate keys and table redefinitions are rejected by the decoder as
      `:parse` / `:syntax` errors.
    * Line/column are included when the decoder reports them.

  Options: `:filename` (used in decoder messages).

  ## Encoding

  See `Formata.Codec.TOML.Encoder` for the accepted domain. `nil` has no TOML
  representation and is rejected; use `Formata.Transform.drop_nils/1` or
  `Formata.Transform.replace_nils/2` explicitly when that loss is acceptable.
  """

  @behaviour Formata.Codec

  alias Formata.Error

  @impl true
  def format, do: :toml

  @impl true
  def decode(input, opts \\ [])

  def decode(input, opts) when is_binary(input) and is_list(opts) do
    toml_opts = [keys: :strings] ++ Keyword.take(opts, [:filename])

    case Formata.Toml.decode(input, toml_opts) do
      {:ok, data} ->
        {:ok, data}

      {:error, {:invalid_toml, message}} = error ->
        Error.error(:parse, :syntax, String.trim(message),
          backend: Formata.Toml,
          format: :toml,
          location: location(message),
          cause: error
        )

      {:error, reason} = error ->
        Error.error(:parse, :syntax, "invalid TOML: #{inspect(reason)}",
          backend: Formata.Toml,
          format: :toml,
          cause: error
        )
    end
  end

  # gsmlg_toml embeds "on line N" and "at column M" in its messages.
  defp location(message) do
    line = Regex.run(~r/on line (\d+)/, message, capture: :all_but_first)
    column = Regex.run(~r/at column (\d+)/, message, capture: :all_but_first)

    case {line, column} do
      {[l], [c]} -> %{line: String.to_integer(l), column: String.to_integer(c)}
      {[l], nil} -> %{line: String.to_integer(l)}
      _ -> nil
    end
  end

  @impl true
  def encode(data, opts \\ []) when is_list(opts), do: Formata.Codec.TOML.Encoder.encode(data)
end
