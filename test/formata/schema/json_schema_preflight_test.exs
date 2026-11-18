defmodule Formata.Schema.JSONSchemaPreflightTest do
  use ExUnit.Case, async: true
  alias Formata.{Error, Schema}
  alias Formata.Schema.JSONSchema

  test "meta-schema checks reject malformed unused constraints before compilation" do
    for document <- [%{"required" => true}, %{"anyOf" => [true, %{"required" => true}]}] do
      assert {:error, [%Error{kind: :schema} | _]} = JSONSchema.check_document(document)
      assert {:error, [%Error{kind: :schema} | _]} = Schema.json_schema(document)
    end

    assert :ok = JSONSchema.check_document(true)
    assert :ok = JSONSchema.check_document(%{"type" => "string"}, dialect: :draft7)
  end

  test "preflight audits unresolved references in unused branches and definitions" do
    for document <- [
          %{"anyOf" => [true, %{"$ref" => "#/$defs/missing"}]},
          %{"$defs" => %{"unused" => %{"$ref" => "#missing"}}},
          %{"then" => %{"$ref" => "#missing"}}
        ] do
      assert {:error, [%Error{kind: :schema, code: :unresolved_ref, schema_path: path}]} =
               JSONSchema.preflight(document)

      assert List.last(path) == "$ref"
    end
  end

  test "resolves recursive pointers, embedded IDs, anchors and dynamic anchors offline" do
    document = %{
      "$id" => "https://example.test/root",
      "$defs" => %{
        "recursive" => %{"$dynamicAnchor" => "node", "$dynamicRef" => "#node"},
        "child" => %{
          "$id" => "child",
          "$defs" => %{"v" => %{"$anchor" => "value", "type" => "integer"}},
          "anyOf" => [%{"$ref" => "#value"}, %{"$ref" => "#/$defs/v"}]
        }
      },
      "anyOf" => [%{"$ref" => "#"}, %{"$ref" => "child#value"}]
    }

    assert {:ok, %Schema{}} = JSONSchema.preflight(document)

    assert {:ok, _} =
             JSONSchema.preflight(%{
               "$id" => "urn:example:root",
               "$defs" => %{"a/b" => %{"$ref" => "#"}},
               "$ref" => "#/$defs/a~1b"
             })
  end

  test "only schema locations are audited, annotation and instance values are ignored" do
    assert {:ok, _} =
             JSONSchema.preflight(%{
               "default" => %{"$ref" => "missing"},
               "const" => %{"required" => true}
             })
  end

  test "built-in schema references are audited without an external loader" do
    assert {:ok, compiled} =
             JSONSchema.preflight(%{
               "$ref" => "https://json-schema.org/draft/2020-12/meta/validation"
             })

    assert :ok = Formata.validate(%{"type" => "string"}, compiled)
    assert {:error, _} = Formata.validate(%{"required" => true}, compiled)
  end

  test "external loaders are explicit, bounded and captured for later validation" do
    document = %{"$ref" => "https://example.test/external#/$defs/value"}
    assert {:error, [%Error{code: :unresolved_ref}]} = JSONSchema.preflight(document)
    external = %{"$defs" => %{"value" => %{"type" => "integer"}}}

    assert {:ok, compiled} =
             JSONSchema.preflight(document,
               registry: %{"https://example.test/external" => external}
             )

    assert :ok = Formata.validate(2, compiled)
    assert {:error, _} = Formata.validate("x", compiled)

    loader = fn uri ->
      send(self(), {:loaded, uri})
      {:ok, external}
    end

    assert {:ok, compiled} = JSONSchema.preflight(document, loader: loader)
    assert_received {:loaded, "https://example.test/external"}
    assert :ok = Formata.validate(3, compiled)
    refute_received {:loaded, _}

    assert {:error, [%Error{kind: :schema} | _]} =
             JSONSchema.preflight(document, loader: fn _ -> {:ok, %{"required" => true}} end)

    assert {:error, [%Error{code: :unresolved_ref}]} =
             JSONSchema.preflight(document,
               loader: fn _ -> {:ok, %{"$defs" => %{"value" => %{"$ref" => "#missing"}}}} end
             )
  end

  test "registration limits apply before loading or compilation" do
    for opts <- [
          [max_depth: 0],
          [max_nodes: 1],
          [max_bytes: 1],
          [max_refs: 0],
          [max_resources: 0]
        ] do
      assert {:error, [%Error{code: :limit_exceeded}]} =
               JSONSchema.preflight(%{"$ref" => "remote", "$defs" => %{"x" => %{}}}, opts)
    end

    assert {:error, [%Error{code: :invalid_option}]} = JSONSchema.preflight(%{}, max_refs: -1)
  end

  test "a resource ID alias does not consume a second resource slot" do
    assert {:ok, _} =
             JSONSchema.preflight(%{"$id" => "https://example.test/root", "$ref" => "#"},
               max_resources: 1
             )
  end

  test "Draft 7 tuple items and fragment IDs retain their dialect and scopes" do
    document = %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "$id" => "https://example.test/root",
      "definitions" => %{"v" => %{"$id" => "#value", "type" => "integer"}},
      "items" => [%{"$ref" => "#value"}]
    }

    assert {:ok, compiled} = JSONSchema.preflight(document)
    assert :ok = Formata.validate([1], compiled)
    assert {:error, _} = Formata.validate(["x"], compiled)
  end

  test "duplicate anchors and malformed loader base metadata fail structurally" do
    assert {:error, [%Error{code: :invalid_schema}]} =
             JSONSchema.preflight(%{
               "$defs" => %{"a" => %{"$anchor" => "same"}, "b" => %{"$anchor" => "same"}},
               "$ref" => "#same"
             })

    assert {:error, [%Error{code: :unresolved_ref}]} =
             JSONSchema.preflight(%{"$ref" => "remote"},
               loader: fn _ -> {:ok, %{document: %{}, base_uri: nil}} end
             )
  end

  test "external cycles, retrieval base overrides and pointer targets are audited" do
    registry = %{
      "https://example.test/a" => %{"$ref" => "https://example.test/b"},
      "https://example.test/b" => %{"$ref" => "https://example.test/a"}
    }

    assert {:ok, _} =
             JSONSchema.preflight(%{"$ref" => "https://example.test/a"}, registry: registry)

    loader = fn "https://example.test/requested" ->
      {:ok,
       %{
         document: %{"$defs" => %{"v" => %{"type" => "string"}}, "$ref" => "#/$defs/v"},
         base_uri: "https://example.test/effective"
       }}
    end

    assert {:ok, compiled} =
             JSONSchema.preflight(%{"$ref" => "https://example.test/requested"}, loader: loader)

    assert :ok = Formata.validate("ok", compiled)

    assert {:error, [%Error{code: :unresolved_ref}]} =
             JSONSchema.preflight(%{
               "x-schema" => %{"$ref" => "#missing"},
               "$ref" => "#/x-schema"
             })

    assert {:error, [%Error{code: :unresolved_ref}]} =
             JSONSchema.preflight(%{"$ref" => "#/default", "default" => 42})
  end
end
