defmodule Formata.JSONSchema.JSON do
  @moduledoc false

  # Formata fork: always delegates to Elixir's built-in JSON (Elixir >= 1.18).
  defdelegate decode(data), to: JSON
  defdelegate decode!(data), to: JSON
  defdelegate encode!(data), to: JSON
  defdelegate encode_to_iodata!(data), to: JSON
end
