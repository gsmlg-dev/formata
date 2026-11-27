Code.require_file("../../../scripts/fixtures/dialyzer/native_export_probe.ex", __DIR__)

defmodule Formata.Schema.NativeExportDialyzerTest do
  use ExUnit.Case, async: true

  test "the original downstream probe exports the required field without changing wire shape" do
    expected = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}},
      "required" => ["name"]
    }

    assert NativeExportProbe.project(%{name: {:required, :string}}) == expected
    assert NativeExportProbe.project(name: {:required, :string}) == expected
  end

  test "empty map and keyword definitions remain successful exports" do
    expected = %{"type" => "object", "properties" => %{}}

    assert NativeExportProbe.project(%{}) == expected
    assert NativeExportProbe.project([]) == expected
  end

  test "the original downstream probe still raises the structured schema error" do
    error =
      assert_raise Formata.Error, fn ->
        NativeExportProbe.project(%{name: :not_a_type})
      end

    assert error.kind == :schema
    assert error.code == :invalid_schema
    assert error.schema_path == [:name]
    assert error.backend == Formata.NativeSchema
  end
end
