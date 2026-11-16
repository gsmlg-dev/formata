# Regression tests for changes made in Formata's fork of backplane_json_schema
# 1.10.76 (not part of the upstream suite).
defmodule Formata.JSONSchema.ForkFixesTest do
  use ExUnit.Case, async: true

  alias Formata.JSONSchema
  alias Formata.JSONSchema.Compiler.Predicates.MultipleOf
  alias Formata.JSONSchema.Formats

  doctest MultipleOf

  describe "gsmlg-opt/backplane#170: format is an annotation without $schema" do
    test "a document without $schema does not assert format unless asked" do
      for document <- [
            %{"type" => "string", "format" => "email"},
            %{"properties" => %{"a" => %{"format" => "email"}}},
            %{"$defs" => %{"e" => %{"format" => "email"}}, "$ref" => "#/$defs/e"}
          ] do
        data = if Map.has_key?(document, "properties"), do: %{"a" => "x"}, else: "x"

        {:ok, default} = JSONSchema.compile(document)
        assert :ok = JSONSchema.validate(default, data)

        {:ok, disabled} = JSONSchema.compile(document, format_assertion: false)
        assert :ok = JSONSchema.validate(disabled, data)

        {:ok, enabled} = JSONSchema.compile(document, format_assertion: true)
        assert {:error, [%{rule: :format}]} = JSONSchema.validate(enabled, data)
      end
    end

    test "a remote resource without $schema follows the same default" do
      loader = fn "https://example.com/email.json" -> {:ok, %{"format" => "email"}} end
      document = %{"$ref" => "https://example.com/email.json"}

      {:ok, default} = JSONSchema.compile(document, loader: loader)
      assert :ok = JSONSchema.validate(default, "x")

      {:ok, enabled} = JSONSchema.compile(document, loader: loader, format_assertion: true)
      assert {:error, [%{rule: :format}]} = JSONSchema.validate(enabled, "x")
    end

    test "a custom meta-schema can still enable the format-assertion vocabulary" do
      vocab = "https://json-schema.org/draft/2020-12/vocab/"

      metas = %{
        "https://example.com/assert" => %{
          "$vocabulary" => %{(vocab <> "core") => true, (vocab <> "format-assertion") => true}
        },
        "https://example.com/plain" => %{}
      }

      loader = &Map.fetch(metas, &1)

      {:ok, asserting} =
        JSONSchema.compile(%{"$schema" => "https://example.com/assert", "format" => "email"},
          loader: loader
        )

      assert {:error, [%{rule: :format}]} = JSONSchema.validate(asserting, "x")

      # A meta-schema without $vocabulary gets the standard default vocabularies.
      {:ok, plain} =
        JSONSchema.compile(%{"$schema" => "https://example.com/plain", "format" => "email"},
          loader: loader
        )

      assert :ok = JSONSchema.validate(plain, "x")
    end
  end

  describe "gsmlg-opt/backplane#172: format_error renders JSON Pointer paths" do
    test "integer segments are decimal text and `~`/`/` are escaped" do
      {:ok, schema} =
        JSONSchema.compile(%{
          "properties" => %{
            "a" => %{"items" => %{"type" => "string"}},
            "b/c~d" => %{"type" => "string"}
          }
        })

      {:error, errors} = JSONSchema.validate(schema, %{"a" => ["x", 2], "b/c~d" => 1})

      assert errors |> Enum.map(&JSONSchema.format_error/1) |> Enum.sort() == [
               "At /a/1: Expected type string, got integer",
               "At /b~1c~0d: Expected type string, got integer"
             ]

      {:error, [error]} = JSONSchema.validate(schema, %{"a" => [10]})
      assert JSONSchema.format_error(error) == "At /a/0: Expected type string, got integer"
    end
  end

  describe "multipleOf without Decimal" do
    test "never raises and compares exact decimals" do
      for {divisor, data, valid?} <- [
            # float division overflows: upstream's native fallback raised
            {0.123456789, 1.0e308, false},
            {0.5, 1.0e308, true},
            {0.1, 10 ** 400, true},
            {0.3, 10 ** 400 + 1, false},
            # within upstream's 1.0e-9 tolerance, but not a multiple
            {1, 1.0e-10, false},
            {1, 1.0000000001, false},
            {0.0001, 0.0075, true},
            {0.01, 0.075, false},
            {1.0e-8, 12_391_239_123, true},
            {2, -4, true},
            {2, -3, false},
            {1.5, 0, true},
            {1.5, -0.0, true}
          ] do
        {:ok, schema} = JSONSchema.compile(%{"multipleOf" => divisor})
        result = JSONSchema.validate(schema, data)

        assert result == :ok == valid?,
               "#{inspect(data)} multipleOf #{inspect(divisor)}: #{inspect(result)}"
      end
    end
  end

  describe "IDNA-dependent formats are indeterminate, never raised, passed or failed" do
    @a_label "xn--4gbwdl.xn--wgbh1c"

    test "Formats.validate/2 reports undecidable input as indeterminate" do
      for {format, value} <- [
            {"hostname", @a_label},
            {"hostname", "example.XN--wgbh1c"},
            {"email", "a@" <> @a_label},
            {"idn-hostname", @a_label},
            {"idn-hostname", "실례.테스트"},
            {"idn-hostname", "실례。테스트"},
            {"idn-email", "실례@실례.테스트"}
          ] do
        assert {:indeterminate, %{contrast: ^format, input: ^value, error_detail: detail}} =
                 Formats.validate(format, value)

        assert detail =~ "IDNA2008"
      end
    end

    test "input that is invalid regardless of its IDN labels is still rejected" do
      for {format, value} <- [
            {"hostname", "xn--4gbwdl.under_score"},
            {"hostname", "xn--under_score"},
            {"hostname", "xn--ends-with-hyphen-"},
            {"hostname", "xn--" <> String.duplicate("a", 60)},
            {"hostname", "실례.com"},
            {"email", "not an email@" <> @a_label},
            {"idn-hostname", "실례..테스트"},
            {"idn-hostname", "실례.-leading"},
            {"idn-hostname", String.duplicate("a.", 127) <> "aa"}
          ] do
        assert {:error, %{contrast: ^format}} = Formats.validate(format, value),
               "#{format} #{inspect(value)}"
      end

      for {format, value} <- [
            {"hostname", "example.com"},
            {"idn-hostname", "example.com"},
            {"email", "a@example.com"},
            {"idn-email", "실례@example.com"}
          ] do
        assert :ok = Formats.validate(format, value)
      end
    end

    test "validation aborts with :indeterminate_format that combinators cannot invert" do
      inner = %{"format" => "hostname"}

      for document <- [
            inner,
            %{"not" => inner},
            %{"anyOf" => [inner, %{"type" => "integer"}]},
            %{"oneOf" => [inner, %{"type" => "integer"}]},
            %{"if" => inner, "then" => false, "else" => true},
            %{"items" => inner}
          ],
          opts <- [[], [draft: "draft7"]] do
        {:ok, schema} = JSONSchema.compile(document, [format_assertion: true] ++ opts)
        data = if Map.has_key?(document, "items"), do: ["ok.com", @a_label], else: @a_label

        assert {:error, [%{rule: :indeterminate_format} = error]} =
                 JSONSchema.validate(schema, data),
               inspect(document)

        if is_list(data), do: assert(error.path == [1])

        assert JSONSchema.format_error(error) =~
                 "Cannot determine whether \"#{@a_label}\" is a valid hostname"
      end

      # Without format assertion the value is never inspected.
      {:ok, schema} = JSONSchema.compile(%{"not" => inner})
      assert {:error, [%{rule: :not}]} = JSONSchema.validate(schema, @a_label)
    end
  end

  describe "opaque base URIs resolve on every supported Elixir version" do
    alias Formata.JSONSchema.URIUtil

    test "fragment, query and relative references keep a hostless base" do
      base = "urn:uuid:deadbeef-1234-ff00-00ff-4321feebdaed"
      assert URIUtil.resolve(base, "#something") == base <> "#something"
      assert URIUtil.resolve(base <> "#old", "#new") == base <> "#new"
      assert URIUtil.resolve(base, "https://example.com/a") == "https://example.com/a"
      assert URIUtil.resolve("https://example.com/a/b", "c#d") == "https://example.com/a/c#d"
    end

    test "a URN $id with an anchor $ref validates through the anchor" do
      {:ok, schema} =
        JSONSchema.compile(
          %{
            "$id" => "urn:uuid:deadbeef-1234-ff00-00ff-4321feebdaed",
            "properties" => %{
              "foo" => %{"$ref" => "urn:uuid:deadbeef-1234-ff00-00ff-4321feebdaed#something"}
            },
            "definitions" => %{"bar" => %{"$id" => "#something", "type" => "string"}}
          },
          dialect: "draft7"
        )

      assert :ok = JSONSchema.validate(schema, %{"foo" => "bar"})
      assert {:error, [%{rule: :type}]} = JSONSchema.validate(schema, %{"foo" => 12})
    end
  end
end
