defmodule NativeSchemaProbe do
  def compile(definition) do
    case Formata.Schema.native(definition) do
      {:ok, schema} -> schema
      {:error, [error | _]} -> raise error
    end
  end

  def compile_with_options(definition, opts) do
    case Formata.Schema.Native.compile(definition, opts) do
      {:ok, schema} -> schema
      {:error, [error | _]} -> raise error
    end
  end

  # The list-to-map dispatch is the second failure reported by Backplane.
  def project(schema) when is_list(schema), do: schema |> Map.new() |> project()
  def project(schema) when is_map(schema), do: NativeExportProbe.project(schema)
end
