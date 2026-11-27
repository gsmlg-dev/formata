defmodule NativeExportProbe do
  def project(schema) do
    case Formata.Schema.Native.to_json_schema(schema,
           exclude_meta_keys: [:default],
           on_unsupported: :omit
         ) do
      {:ok, document} -> document
      {:error, [error | _]} -> raise error
    end
  end
end
