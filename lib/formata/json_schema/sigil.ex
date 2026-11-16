defmodule Formata.JSONSchema.Sigil do
  @moduledoc """
  Compile-time sigils for static JSON Schema literals.

  The primary sigil is `~X`, chosen to avoid the common `~J` conflict with
  Formata.JSON.Backend while still feeling mnemonic for Formata.JSONSchema.

  The sigil body is parsed as Elixir, not JSON, so the most ergonomic form is
  an Elixir map or boolean literal.

  ## Examples

      iex> import Formata.JSONSchema.Sigil, only: [sigil_X: 2]
      iex> schema = ~X|%{"type" => "integer"}|
      iex> Formata.JSONSchema.validate(schema, 1)
      :ok

      iex> import Formata.JSONSchema.Sigil, only: [sigil_X: 2]
      iex> schema = ~X|%{"type" => "string", "format" => "email"}|f
      iex> {:error, [_]} = Formata.JSONSchema.validate(schema, "not-an-email")
  """

  @doc """
  Imports the `~X` sigil for compile-time schema literals.
  """
  defmacro __using__(_opts) do
    quote do
      import Formata.JSONSchema.Sigil, only: [sigil_X: 2]
    end
  end

  @doc """
  Compile-time sigil for Elixir schema literals.

  Supported modifiers:

  - `f` — `format_assertion: true`
  - `c` — `content_assertion: true`
  """
  defmacro sigil_X({:<<>>, _meta, [string]}, modifiers) when is_binary(string) do
    compile_sigil!(string, modifiers, __CALLER__)
  end

  defmacro sigil_X(_term, _modifiers) do
    raise CompileError,
      file: __CALLER__.file,
      line: __CALLER__.line,
      description:
        "~X does not support interpolation; use Formata.JSONSchema.Schema.compile!/2 for dynamic composition"
  end

  defp compile_sigil!(string, modifiers, caller) do
    opts = sigil_opts!(modifiers, caller)

    schema_ast =
      Code.string_to_quoted!(string,
        file: caller.file,
        line: caller.line
      )

    Formata.JSONSchema.Schema.compile_ast!(schema_ast, opts, caller)
  end

  defp sigil_opts!(modifiers, caller) do
    Enum.reduce(modifiers, [], fn modifier, acc ->
      case modifier do
        ?f -> Keyword.put(acc, :format_assertion, true)
        ?c -> Keyword.put(acc, :content_assertion, true)
        other -> raise_compile_error!(caller, "unsupported ~X modifier: #{<<other>>}")
      end
    end)
  end

  defp raise_compile_error!(caller, description) do
    raise CompileError,
      file: caller.file,
      line: caller.line,
      description: description
  end
end
