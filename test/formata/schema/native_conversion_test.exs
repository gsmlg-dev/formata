defmodule Formata.Schema.NativeConversionTest do
  use ExUnit.Case, async: true
  alias Formata.{Error, Schema}
  alias Formata.Schema.Native

  test "exports discovery schemas with defaults excluded recursively" do
    definition = %{
      limit: {:integer, {:default, 10}},
      nested: %{name: {:meta, :string, description: "Name", default: "x"}}
    }

    assert {:ok, json} = Native.to_json_schema(definition, exclude_meta_keys: [:default])
    assert json["properties"]["limit"] == %{"type" => "integer"}

    assert json["properties"]["nested"]["properties"]["name"] == %{
             "type" => "string",
             "description" => "Name"
           }

    assert {:ok, compiled} = Schema.json_schema(json, dialect: :draft7)
    assert :ok = Formata.validate(%{"limit" => 3}, compiled)
  end

  test "native first-match unions export as anyOf" do
    assert {:ok, %{"anyOf" => [_, _]} = json} =
             Native.to_json_schema({:oneof, [:integer, {:integer, gte: 0}]})

    assert {:ok, schema} = Schema.json_schema(json, dialect: :draft7)
    assert :ok = Formata.validate(1, schema)
  end

  test "custom validators require explicit omission and are never executed" do
    definition = %{value: {:custom, fn _ -> flunk("must not execute") end}}

    assert {:error, [%Error{kind: :unsupported, code: :conversion_unsupported}]} =
             Native.to_json_schema(definition)

    assert {:ok, %{"properties" => %{"value" => %{}}}} =
             Native.to_json_schema(definition, on_unsupported: :omit)
  end

  test "exports reject key collisions and unsupported key constraints" do
    assert {:error, [%Error{}]} = Native.to_json_schema(%{:a => :string, "a" => :integer})

    assert {:error, [%Error{code: :conversion_unsupported}]} =
             Native.to_json_schema({:map, :integer, :string})
  end

  test "imports the supported primitive, list, object and numeric vocabulary" do
    assert {:ok, :string} = Native.from_json_schema(%{"type" => "string"})

    assert {:ok, {:list, :string}} =
             Native.from_json_schema(%{"type" => "array", "items" => %{"type" => "string"}})

    assert {:ok, %{"name" => {:required, :string}}} =
             Native.from_json_schema(%{
               "type" => "object",
               "properties" => %{"name" => %{"type" => "string"}},
               "required" => ["name"]
             })

    assert {:ok, integer} = Native.from_json_schema(%{"type" => "integer", "minimum" => 1})
    assert {:ok, schema} = Schema.native(integer)
    assert :ok = Formata.validate(2.0, schema)
    assert {:error, _} = Formata.validate(0, schema)
  end

  test "rejects unsupported constraints, mixed assertions and invalid schemas" do
    for document <- [
          %{"oneOf" => [%{"type" => "integer"}, %{"type" => "number"}]},
          %{"type" => "string", "format" => "date"},
          %{"type" => "object", "additionalProperties" => false},
          %{"type" => "string", "enum" => ["abc"], "minLength" => 4},
          %{"type" => "string", "anyOf" => [%{"const" => "x"}]},
          %{"type" => "array", "contains" => %{"type" => "string"}}
        ] do
      assert {:error, [%Error{kind: :unsupported, code: :conversion_unsupported}]} =
               Native.from_json_schema(document)
    end

    assert {:error, [%Error{kind: :schema, schema_path: ["required"]} | _]} =
             Native.from_json_schema(%{"type" => "object", "required" => true})

    assert {:error, _} = Native.from_json_schema(%{"type" => "string", "pattern" => "["})
    assert {:error, [%Error{code: :invalid_option}]} = Native.from_json_schema(%{}, keys: :atoms!)
  end
end
