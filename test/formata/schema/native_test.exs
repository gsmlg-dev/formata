defmodule Formata.Schema.NativeTest do
  use ExUnit.Case, async: true

  alias Formata.Error
  alias Formata.Schema
  alias Formata.Test.Schemas

  defp native!(definition) do
    {:ok, schema} = Schema.native(definition)
    schema
  end

  describe "schema creation and checking" do
    test "compiles definitions and keeps backend metadata" do
      definition = %{name: {:required, :string}}

      assert {:ok,
              %Schema{kind: :native, dialect: nil, backend: Formata.Backplane.Schema} = schema} =
               Schema.compile(:native, definition)

      assert schema.compiled == definition
      assert schema.source == definition
    end

    test "invalid definitions are schema errors, separate from data validation" do
      assert {:error, [%Error{kind: :schema, code: :invalid_schema, schema_path: [:age]}]} =
               Schema.native(%{age: :intger})

      assert {:error, [%Error{kind: :schema}]} = Schema.check(:native, {:list, :nope})
      assert :ok = Schema.check(:native, %{age: :integer})
    end

    test "unknown schema kind is unsupported" do
      assert {:error, [%Error{kind: :unsupported, code: :unknown_schema_kind}]} =
               Schema.compile(:xsd, %{})
    end

    test "composition helpers delegate to Formata.Backplane.Schema" do
      base = %{name: :string, age: :integer}

      assert {:ok, %{name: :string, age: :integer, email: :string}} =
               Schema.Native.merge(base, %{email: :string})

      assert {:ok, %{name: :string}} = Schema.Native.select(base, [:name])
      assert {:ok, %{age: :integer}} = Schema.Native.except(base, [:name])
    end
  end

  describe "pure validation" do
    setup do
      definition = %{
        name: {:required, {:string, min: 1}},
        age: {:integer, gte: 0},
        role: {:enum, ["admin", "member"]},
        tags: {:list, :string},
        address: %{city: {:required, :string}, zip: {:string, regex: ~r/^\d{5}$/}},
        contacts: {:list, %{kind: {:required, :string}}}
      }

      %{schema: native!(definition)}
    end

    test "valid nested data", %{schema: schema} do
      data = %{
        "name" => "Ada",
        "age" => 36,
        "role" => "admin",
        "tags" => ["math"],
        "address" => %{"city" => "London", "zip" => "12345"},
        "contacts" => [%{"kind" => "email"}]
      }

      assert :ok = Formata.validate(data, schema)
    end

    test "violations carry data paths using the data's own keys", %{schema: schema} do
      data = %{
        "name" => "",
        "age" => -1,
        "role" => "root",
        "tags" => ["ok", 1],
        "address" => %{"zip" => "x"},
        "contacts" => [%{"kind" => "a"}, %{}]
      }

      assert {:error, errors} = Formata.validate(data, schema)

      assert Enum.all?(
               errors,
               &(&1.kind == :validation and &1.backend == Formata.Backplane.Schema)
             )

      by_path = Map.new(errors, &{&1.path, &1.code})
      assert by_path[["name"]] == :min
      assert by_path[["age"]] == :gte
      assert by_path[["role"]] == :enum
      assert by_path[["tags", 1]] == :type
      assert by_path[["address", "city"]] == :required
      assert by_path[["address", "zip"]] == :regex
      assert by_path[["contacts", 1, "kind"]] == :required
    end

    test "a numeric string fails a pure integer validation; cast may coerce it" do
      strict = native!(%{"n" => :integer})

      assert {:error, [%Error{kind: :validation, code: :type, path: ["n"]}]} =
               Formata.validate(%{"n" => "42"}, strict)

      coercing = native!(%{"n" => {:coerce, :integer}})
      assert {:ok, %{"n" => 42}} = Formata.cast(%{"n" => "42"}, coercing)

      assert {:error,
              [%Error{kind: :unsupported, code: :pure_validation_unsupported, schema_path: ["n"]}]} =
               Formata.validate(%{"n" => "42"}, coercing)

      assert {:error, [%Error{kind: :transform, code: :coercion, path: ["n"]}]} =
               Formata.cast(%{"n" => "forty"}, coercing)
    end

    test "missing required values never succeed through defaults" do
      required = native!(%{"port" => {:required, :integer}})

      assert {:error, [%Error{code: :required, path: ["port"]}]} =
               Formata.validate(%{}, required)

      defaulted = native!(%{"port" => {:integer, {:default, 80}}})

      assert {:error, [%Error{kind: :unsupported, code: :pure_validation_unsupported}]} =
               Formata.validate(%{}, defaulted)

      assert {:ok, %{"port" => 80}} = Formata.cast(%{}, defaulted)
    end

    test "transforming constructs are reported before running, with their schema path" do
      for {definition, path} <- [
            {%{a: {:string, {:transform, &String.upcase/1}}}, [:a]},
            {%{a: {:string, {:encode, &String.upcase/1}}}, [:a]},
            {%{a: %{b: {:list, {:default, []}}}}, [:a, :b]},
            {%{a: {:coerce, :string, :integer}}, [:a]},
            {%{a: {:integer, [gt: 0, default: 1]}}, [:a]},
            {%{a: {:dependent, fn _ -> {:ok, :integer} end}}, [:a]},
            {%{a: {:ref, {Schemas, :with_default}}},
             [:a, {:ref, {Schemas, :with_default}}, :port]}
          ] do
        schema = native!(definition)
        test_pid = self()
        data = %{"a" => tracer(test_pid)}

        assert {:error, [%Error{kind: :unsupported, schema_path: ^path} | _]} =
                 Formata.validate(data, schema),
               "expected #{inspect(definition)} to be rejected at #{inspect(path)}"
      end
    end

    test "the caller's data is never modified", %{schema: schema} do
      data = %{"name" => "Ada", "extra" => 1, "address" => %{"city" => "x", "more" => true}}
      snapshot = :erlang.term_to_binary(data)
      assert :ok = Formata.validate(data, schema)
      assert :erlang.term_to_binary(data) == snapshot
    end

    test "custom validators stay enforced, including ones JSON Schema cannot express" do
      schema =
        native!(%{
          "n" => {:custom, &Schemas.even/1},
          "m" => {:custom, {Schemas, :even}},
          "sum" =>
            {:custom,
             fn v, root ->
               if v == root["n"] + root["m"], do: :ok, else: {:error, "bad sum", []}
             end}
        })

      assert :ok = Formata.validate(%{"n" => 2, "m" => 4, "sum" => 6}, schema)

      assert {:error, errors} = Formata.validate(%{"n" => 3, "m" => 5, "sum" => 1}, schema)

      assert errors |> Enum.map(&{&1.path, &1.code}) |> Enum.sort() == [
               {["m"], :custom},
               {["n"], :custom},
               {["sum"], :custom}
             ]

      assert Enum.find(errors, &(&1.path == ["n"])).message == "3 is not even"
    end

    test "custom validators that return a new value are not accepted as pure" do
      schema = native!(%{"n" => {:enum, [10], type: {:custom, fn v -> {:ok, v * 10} end}}})

      # Formata.Backplane.Schema itself would accept this by checking the modified value.
      assert {:ok, _} = Formata.Backplane.Schema.validate(schema.compiled, %{"n" => 1})

      assert {:error, [%Error{kind: :unsupported, code: :non_pure_custom, path: ["n"]}]} =
               Formata.validate(%{"n" => 1}, schema)
    end

    test "recursive references through defschema" do
      schema = native!({:ref, {Schemas, :person}})

      assert :ok =
               Formata.validate(
                 %{
                   "name" => "a",
                   "address" => %{"city" => "x"},
                   "friends" => [%{"name" => "b", "friends" => [%{"name" => "c"}]}]
                 },
                 schema
               )

      assert {:error, [%Error{code: :required, path: ["friends", 0, "friends", 0, "name"]}]} =
               Formata.validate(
                 %{"name" => "a", "friends" => [%{"name" => "b", "friends" => [%{}]}]},
                 schema
               )

      assert {:error, [%Error{code: :regex, path: ["address", "zip"]}]} =
               Formata.validate(
                 %{"name" => "a", "address" => %{"city" => "x", "zip" => "no"}},
                 schema
               )
    end

    test "unresolvable references are schema errors" do
      assert {:ok, schema} = Schema.native(%{a: {:ref, {Schemas, :missing}}})

      assert {:error, [%Error{kind: :schema, code: :unresolved_ref}]} =
               Formata.validate(%{"a" => 1}, schema)
    end

    test "native oneof keeps native first-match semantics" do
      schema = native!(%{"v" => {:oneof, [:integer, {:integer, gt: 0}]}})
      assert :ok = Formata.validate(%{"v" => 5}, schema)
    end

    test "scalar schemas and roots" do
      assert :ok = Formata.validate(5, native!({:integer, gt: 1}))

      assert {:error, [%Error{code: :gt, path: []}]} =
               Formata.validate(0, native!({:integer, gt: 1}))

      assert {:error, [%Error{code: :type}]} =
               Formata.validate([1, "x"], native!({:list, :integer}))
    end
  end

  describe "unknown fields" do
    setup do
      %{schema: native!(%{name: :string, address: %{city: :string}})}
    end

    test "validate allows unknown fields by default", %{schema: schema} do
      assert :ok =
               Formata.validate(
                 %{"name" => "a", "x" => 1, "address" => %{"city" => "c", "y" => 2}},
                 schema
               )
    end

    test "validate can reject unknown fields at every level", %{schema: schema} do
      data = %{"name" => "a", "x" => 1, "z" => 3, "address" => %{"city" => "c", "y" => 2}}

      # The native engine checks a map's undeclared keys after its declared
      # fields pass, so nested unknown fields are reported first.
      assert {:error, [%Error{kind: :validation, code: :unknown_field, path: ["address", "y"]}]} =
               Formata.validate(data, schema, unknown: :reject)

      data = put_in(data, ["address"], %{"city" => "c"})
      assert {:error, errors} = Formata.validate(data, schema, unknown: :reject)
      assert Enum.all?(errors, &(&1.kind == :validation and &1.code == :unknown_field))
      assert errors |> Enum.map(& &1.path) |> Enum.sort() == [["x"], ["z"]]
      assert :ok = Formata.validate(%{"name" => "a"}, schema, unknown: :reject)
    end

    test "stripping is only available through cast", %{schema: schema} do
      assert {:error, [%Error{kind: :unsupported, code: :invalid_option}]} =
               Formata.validate(%{}, schema, unknown: :strip)

      data = %{"name" => "a", "x" => 1, "address" => %{"city" => "c", "y" => 2}}
      assert {:ok, %{name: "a", address: %{city: "c"}}} = Formata.cast(data, schema)

      assert {:ok, %{name: "a", address: %{city: "c"}}} =
               Formata.cast(data, schema, unknown: :strip)

      # the input is untouched
      assert data["x"] == 1
    end

    test "cast can reject or keep unknown fields" do
      string_keyed = native!(%{"name" => :string, "n" => {:coerce, :integer}})

      assert {:ok, %{"name" => "a", "n" => 1, "x" => true}} =
               Formata.cast(%{"name" => "a", "n" => "1", "x" => true}, string_keyed,
                 unknown: :allow
               )

      assert {:error, [%Error{code: :unknown_field, path: ["x"]}]} =
               Formata.cast(%{"name" => "a", "x" => true}, string_keyed, unknown: :reject)

      assert {:ok, %{"name" => "a", "n" => 1}} =
               Formata.cast(%{"name" => "a", "n" => "1"}, string_keyed, unknown: :reject)
    end

    test "cast unknown: :allow with atom-keyed schemas keeps the data's own keys",
         %{schema: schema} do
      # Regression for gsmlg-opt/backplane#171 (fixed in the fork): permissive
      # mode used to add updated values under atom keys next to the string keys.
      data = %{"name" => "a", "x" => 1, "address" => %{"city" => "c", "y" => 2}}
      assert {:ok, result} = Formata.cast(data, schema, unknown: :allow)
      assert result == data

      coercing =
        native!(%{
          n: {:coerce, :integer},
          u: %{m: {:coerce, :integer}},
          l: {:list, %{k: {:coerce, :integer}}},
          d: {:integer, {:default, 7}}
        })

      assert {:ok, result} =
               Formata.cast(
                 %{"n" => "1", "u" => %{"m" => "2"}, "l" => [%{"k" => "3"}], "x" => true},
                 coercing,
                 unknown: :allow
               )

      # A field added by a default has no data key, so it uses the schema key.
      assert result == %{
               "n" => 1,
               "u" => %{"m" => 2},
               "l" => [%{"k" => 3}],
               "x" => true,
               :d => 7
             }

      assert {:ok, %{name: "a", extra: 1}} =
               Formata.cast(%{name: "a", extra: 1}, schema, unknown: :allow)
    end

    test "keyword schemas cannot reject unknown fields" do
      assert {:error, [%Error{kind: :unsupported, code: :unknown_reject_unsupported}]} =
               Formata.validate([name: "a"], native!(name: :string), unknown: :reject)
    end
  end

  describe "cast" do
    test "order of operations: default, then coercion, then constraints, then transform" do
      schema =
        native!(%{
          "a" => {{:coerce, {:integer, gt: 5}}, {:default, "6"}},
          "b" => {{:coerce, {:integer, gt: 5}}, {:transform, &Integer.to_string/1}},
          "c" => {{:integer, {:transform, &(&1 * 10)}}, {:default, 2}}
        })

      # a: the default is coerced and checked like input; b: the coerced value
      # is checked before the transform; c: the default is transformed.
      assert {:ok, %{"a" => 6, "b" => "6", "c" => 20}} = Formata.cast(%{"b" => "6"}, schema)

      # constraints apply to the coerced value, before the transform runs
      assert {:error, [%Error{code: :gt, path: ["b"]}]} = Formata.cast(%{"b" => "5"}, schema)

      # an explicit value replaces the default and is still validated
      assert {:error, [%Error{code: :gt, path: ["a"]}]} =
               Formata.cast(%{"a" => "1", "b" => "6"}, schema)
    end

    test "transforms only run on present values" do
      schema = native!(%{"t" => {:integer, {:transform, &(&1 * 10)}}})
      assert {:ok, %{}} = Formata.cast(%{}, schema)
      assert {:ok, %{"t" => 30}} = Formata.cast(%{"t" => 3}, schema)
    end

    test "a default can never satisfy a required field" do
      # Formata.Backplane.Schema rejects this combination when the schema is checked.
      assert {:error, [%Error{kind: :schema, schema_path: ["port"]}]} =
               Schema.native(%{"port" => {:required, {:integer, {:default, 80}}}})
    end

    test "coercion to :atom! is refused" do
      schema = native!(%{"k" => {:coerce, :atom!}})

      assert {:error, [%Error{kind: :unsupported, code: :unsafe_atom_coercion}]} =
               Formata.cast(
                 %{"k" => "never_created_atom_#{System.unique_integer([:positive])}"},
                 schema
               )
    end

    test "cast keeps the full native engine" do
      schema = native!({:ref, {Schemas, :with_default}})
      assert {:ok, %{port: 80}} = Formata.cast(%{}, schema)
      assert {:ok, %{port: 81}} = Formata.cast(%{"port" => 81}, schema)
    end
  end

  # A value that fails loudly if any custom code receives it.
  defp tracer(pid), do: {:formata_tracer, pid}
end
