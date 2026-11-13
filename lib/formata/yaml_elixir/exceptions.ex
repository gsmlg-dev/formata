defmodule Formata.YamlElixir.FileNotFoundError do
  defexception message: "file error"
  @type t :: %__MODULE__{message: String.t()}
end

defmodule Formata.YamlElixir.ParsingError do
  defexception [:line, :column, :type, message: "parsing error", details: %{}]

  @type t :: %__MODULE__{
          line: integer() | nil,
          column: integer() | nil,
          type: atom() | nil,
          message: String.t()
        }

  @impl true
  def message(%__MODULE__{message: message, line: nil, column: nil}), do: message

  def message(%__MODULE__{message: message, line: line, column: column}) do
    message <> " (line: #{line}, column: #{column})"
  end

  def from_yamerl(
        {:formata_yamerl_parsing_error, :error, human_readable_error, line, column, error_type,
         _token_being_parsed, extra}
      ) do
    %__MODULE__{
      message: to_string(human_readable_error),
      line: line,
      column: column,
      type: error_type,
      details: Map.new(extra)
    }
  end

  def from_yamerl(_), do: %__MODULE__{message: "malformed yaml"}
end
