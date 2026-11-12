defmodule Formata.Schema.JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Formata.Error
  alias Formata.Schema

  @draft7 "http://json-schema.org/draft-07/schema#"
  @draft2020 "https://json-schema.org/draft/2020-12/schema"

  defp js!(document, opts \\ []) do
    {:ok, schema} = Schema.json_schema(document, opts)
    schema
  end

  describe "compile" do
    test "keeps kind, dialect, backend representation and source" do
      document = %{"type" => "integer"}
      schema = js!(document)

      assert %Schema{kind: :json_schema, dialect: :draft2020_12, backend: Backplane.JsonSchema} =
               schema

      assert %Backplane.JsonSchema.Types.Schema{} = schema.compiled
      assert schema.source == document
    end

    test "dialect selection: $schema, explicit option, default, and conflicts" do
      assert %Schema{dialect: :draft7} = js!(%{"$schema" => @draft7})
      assert %Schema{dialect: :draft2020_12} = js!(%{"$schema" => @draft2020})
      assert %Schema{dialect: :draft7} = js!(%{"type" => "string"}, dialect: :draft7)
      assert %Schema{dialect: :draft2020_12} = js!(%{"type" => "string"})

      assert {:error, [%Error{kind: :schema, code: :dialect_conflict}]} =
               Schema.json_schema(%{"$schema" => @draft7}, dialect: :draft2020_12)

      assert {:error, [%Error{kind: :unsupported, code: :unknown_dialect}]} =
               Schema.json_schema(%{}, dialect: :draft4)
    end

    test "unrecognized $schema needs an explicit dialect or loader" do
      document = %{"$schema" => "https://example.com/my-meta", "type" => "string"}

      assert {:error, [%Error{kind: :schema, code: :unknown_dialect, schema_path: ["$schema"]}]} =
               Schema.json_schema(document)

      assert %Schema{dialect: :draft2020_12} = js!(document, dialect: :draft2020_12)
    end

    test "boolean schemas" do
      assert :ok = Formata.validate(1, js!(true))

      assert {:error, [%Error{kind: :validation, code: :boolean_schema}]} =
               Formata.validate(1, js!(false))
    end

    test "invalid documents are schema errors" do
      assert {:error, [%Error{kind: :schema, code: :invalid_keyword_value}]} =
               Schema.json_schema(%{"type" => "nope"})

      assert {:error, [%Error{kind: :schema}]} = Schema.json_schema(%{"minimum" => "five"})
      assert {:error, [%Error{kind: :schema, code: :invalid_schema}]} = Schema.json_schema("x")

      assert {:error, [%Error{kind: :schema, code: :invalid_schema}]} =
               Schema.json_schema(%{type: "string"})
    end

    test "extension and unknown keywords are permitted annotations" do
      assert :ok =
               Formata.validate("a", js!(%{"type" => "string", "x-internal" => true, "foo" => 1}))
    end
  end

  describe "validation semantics" do
    test "oneOf rejects a value that matches two branches" do
      schema = js!(%{"oneOf" => [%{"type" => "integer"}, %{"minimum" => 0}]})

      assert {:error, [%Error{kind: :validation, code: :oneOf, backend: Backplane.JsonSchema}]} =
               Formata.validate(5, schema)

      assert :ok = Formata.validate(-5, schema)
      assert :ok = Formata.validate(1.5, schema)
    end

    test "errors carry data paths in document order" do
      schema =
        js!(%{
          "type" => "object",
          "properties" => %{
            "user" => %{"properties" => %{"tags" => %{"items" => %{"type" => "string"}}}}
          }
        })

      assert {:error, [%Error{code: :type, path: ["user", "tags", 1]} = error]} =
               Formata.validate(%{"user" => %{"tags" => ["a", 2]}}, schema)

      assert String.valid?(error.message)
      assert Exception.message(error) == "at /user/tags/1: Expected type string, got integer"
    end

    test "additionalProperties and unevaluatedProperties come from the document only" do
      closed = js!(%{"properties" => %{"a" => true}, "additionalProperties" => false})
      assert :ok = Formata.validate(%{"a" => 1}, closed)

      # additionalProperties: false is reported by the backend as a false boolean subschema
      assert {:error, [%Error{kind: :validation, code: :boolean_schema, path: ["b"]}]} =
               Formata.validate(%{"a" => 1, "b" => 2}, closed)

      unevaluated =
        js!(%{"allOf" => [%{"properties" => %{"a" => true}}], "unevaluatedProperties" => false})

      assert {:error, [%Error{}]} = Formata.validate(%{"a" => 1, "b" => 2}, unevaluated)

      # No facade option can weaken (or otherwise override) the document.
      assert {:error, [%Error{kind: :unsupported, code: :invalid_option}]} =
               Formata.validate(%{"a" => 1, "b" => 2}, closed, unknown: :allow)
    end

    test "default is an annotation: it never satisfies required and is never applied" do
      schema =
        js!(%{
          "type" => "object",
          "required" => ["port"],
          "properties" => %{"port" => %{"type" => "integer", "default" => 80}}
        })

      assert {:error, [%Error{kind: :validation, code: :required}]} =
               Formata.validate(%{}, schema)

      assert {:error, [%Error{kind: :unsupported, code: :cast_unsupported}]} =
               Formata.cast(%{}, schema)
    end

    test "strict JSON types: numeric strings are not integers" do
      schema = js!(%{"type" => "integer"})
      assert {:error, [%Error{code: :type}]} = Formata.validate("42", schema)
      assert :ok = Formata.validate(42, schema)
    end

    test "data outside the JSON data model requires explicit conversion" do
      schema = js!(%{"type" => "object"})

      assert {:error, [%Error{kind: :unsupported, code: :non_json_value, path: ["at"]}]} =
               Formata.validate(%{"at" => ~D[2024-01-01]}, schema)

      assert {:error, [%Error{kind: :unsupported, code: :non_json_value}]} =
               Formata.validate(%{name: "atom key"}, schema)

      {:ok, converted} = Formata.Transform.temporal_to_iso8601(%{"at" => ~D[2024-01-01]})

      assert :ok =
               Formata.validate(
                 converted,
                 js!(%{"properties" => %{"at" => %{"type" => "string"}}})
               )
    end
  end

  describe "dialects" do
    test "Draft 7 semantics (array items, definitions)" do
      schema =
        js!(%{
          "$schema" => @draft7,
          "definitions" => %{"pos" => %{"type" => "integer", "minimum" => 1}},
          "items" => [%{"type" => "string"}, %{"$ref" => "#/definitions/pos"}],
          "additionalItems" => false
        })

      assert :ok = Formata.validate(["a", 1], schema)
      assert {:error, [%Error{code: :minimum, path: [1]}]} = Formata.validate(["a", 0], schema)
      assert {:error, [%Error{}]} = Formata.validate(["a", 1, "extra"], schema)
    end

    test "Draft 2020-12 semantics (prefixItems, $defs, unevaluatedItems)" do
      schema =
        js!(%{
          "$schema" => @draft2020,
          "$defs" => %{"pos" => %{"type" => "integer", "minimum" => 1}},
          "prefixItems" => [%{"type" => "string"}, %{"$ref" => "#/$defs/pos"}],
          "items" => false
        })

      assert :ok = Formata.validate(["a", 1], schema)
      assert {:error, [%Error{code: :minimum, path: [1]}]} = Formata.validate(["a", 0], schema)
      assert {:error, [%Error{}]} = Formata.validate(["a", 1, "extra"], schema)
    end
  end

  describe "references" do
    test "local references, anchors and embedded resources resolve without I/O" do
      schema =
        js!(%{
          "$id" => "https://example.com/root",
          "$defs" => %{
            "name" => %{"$anchor" => "name", "type" => "string", "minLength" => 1},
            "embedded" => %{"$id" => "https://example.com/embedded", "type" => "integer"}
          },
          "properties" => %{
            "a" => %{"$ref" => "#/$defs/name"},
            "b" => %{"$ref" => "#name"},
            "c" => %{"$ref" => "embedded"}
          }
        })

      assert :ok = Formata.validate(%{"a" => "x", "b" => "y", "c" => 1}, schema)
      assert {:error, errors} = Formata.validate(%{"a" => "", "b" => 1, "c" => "z"}, schema)
      assert errors |> Enum.map(& &1.path) |> Enum.sort() == [["a"], ["b"], ["c"]]
    end

    test "recursive local references" do
      schema =
        js!(%{
          "type" => "object",
          "properties" => %{"children" => %{"type" => "array", "items" => %{"$ref" => "#"}}},
          "required" => ["name"]
        })

      assert :ok =
               Formata.validate(
                 %{"name" => "a", "children" => [%{"name" => "b", "children" => []}]},
                 schema
               )

      assert {:error, [%Error{code: :required, path: ["children", 0]}]} =
               Formata.validate(%{"name" => "a", "children" => [%{}]}, schema)
    end

    test "unresolvable references fail as schema errors and never pass silently" do
      dangling = js!(%{"$ref" => "#/$defs/missing"})

      assert {:error, [%Error{kind: :schema, code: :unresolved_ref}]} =
               Formata.validate(1, dangling)

      remote = js!(%{"$ref" => "https://example.com/remote.json"})

      assert {:error, [%Error{kind: :schema, code: :unresolved_ref}]} =
               Formata.validate(1, remote)
    end

    test "remote references load only through an explicit loader" do
      parent = self()

      loader = fn uri ->
        send(parent, {:loaded, uri})
        {:ok, %{"type" => "integer"}}
      end

      schema = js!(%{"$ref" => "https://example.com/int.json"}, loader: loader)
      assert :ok = Formata.validate(1, schema)
      assert {:error, [%Error{code: :type}]} = Formata.validate("x", schema)
      assert_received {:loaded, "https://example.com/int.json"}
    end
  end

  describe "format assertion" do
    for dialect <- [:draft7, :draft2020_12] do
      test "#{dialect}: format is an annotation by default" do
        schema = js!(%{"type" => "string", "format" => "email"}, dialect: unquote(dialect))
        assert :ok = Formata.validate("not-an-email", schema)
      end

      test "#{dialect}: format_assertion: true asserts known formats" do
        schema =
          js!(%{"type" => "string", "format" => "email"},
            dialect: unquote(dialect),
            format_assertion: true
          )

        assert :ok = Formata.validate("ada@example.com", schema)

        assert {:error, [%Error{kind: :validation, code: :format}]} =
                 Formata.validate("not-an-email", schema)

        date = js!(%{"format" => "date-time"}, dialect: unquote(dialect), format_assertion: true)
        assert {:error, [%Error{code: :format}]} = Formata.validate("yesterday", date)
      end
    end

    test "default dialect without $schema is annotation-only too" do
      # WORKAROUND(upstream): gsmlg-opt/backplane#170 makes this hold.
      assert :ok = Formata.validate("x", js!(%{"format" => "email"}))

      assert {:error, [%Error{code: :format}]} =
               Formata.validate("x", js!(%{"format" => "email"}, format_assertion: true))
    end

    test "unknown formats are accepted even when asserting" do
      assert :ok = Formata.validate("x", js!(%{"format" => "made-up"}, format_assertion: true))
    end
  end
end
