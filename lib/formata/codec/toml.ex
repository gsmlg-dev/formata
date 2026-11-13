defmodule Formata.Codec.TOML do
  @moduledoc """
  TOML codec: decoding with `Formata.Toml.decode/2` (forked from `gsmlg_toml`), encoding with
  `Formata.Codec.TOML.Encoder`.

  ## Decoding

    * The root is always a map (table); keys stay strings.
    * `inf`, `-inf`, `nan` become `:infinity`, `:negative_infinity`, `:nan`.
    * Local date, local time, and local date-time become `Date`, `Time`, and
      `NaiveDateTime`.
    * Date-time separators are `T`, `t`, or exactly one ASCII space.
      Fractional seconds retain up to six digits; excess digits are truncated.
    * Offset date-times become UTC `DateTime` values. `Formata.Toml` converts the
      instant to UTC, so the original offset (for example `-08:00`) is not
      preserved; the instant is.
    * Duplicate keys and table redefinitions are rejected by the decoder as
      `:parse` / `:syntax` errors.
    * Line/column are included when the decoder reports them.
    * Comments cannot replace an assignment's value. Arrays allow comments
      and newlines; inline tables allow newlines only within valid values
      such as multiline strings and arrays.

  Options: `:filename` (used in decoder messages).

  ## Encoding

  See `Formata.Codec.TOML.Encoder` for the accepted domain. `nil` has no TOML
  representation and is rejected; use `Formata.Transform.drop_nils/1` or
  `Formata.Transform.replace_nils/2` explicitly when that loss is acceptable.
  Invalid UTF-8 keys return `:encode` / `:invalid_key`, with the containing
  map's path and the offending key in `details.key`.
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

  # Formata.Toml embeds "on line N" and "at column M" in its messages.
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
