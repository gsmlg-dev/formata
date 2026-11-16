defmodule Formata.JSONSchema do
  @moduledoc """
  JSON Schema Draft 2020-12 and Draft 7 validator for Elixir.

  Compile a schema once, then validate data against it repeatedly:

      iex> schema = %{"type" => "integer", "minimum" => 10}
      iex> {:ok, compiled} = Formata.JSONSchema.compile(schema)
      iex> Formata.JSONSchema.validate(compiled, 15)
      :ok
      iex> {:error, [error]} = Formata.JSONSchema.validate(compiled, 5)
      iex> error.rule
      :minimum
      iex> Formata.JSONSchema.format_error(error)
      "Value 5 is less than minimum 10"

  With format assertion:

      iex> schema = %{"type" => "string", "format" => "email"}
      iex> {:ok, compiled} = Formata.JSONSchema.compile(schema, format_assertion: true)
      iex> Formata.JSONSchema.validate(compiled, "user@example.com")
      :ok
      iex> {:error, [error]} = Formata.JSONSchema.validate(compiled, "not-an-email")
      iex> error.rule
      :format
      iex> Formata.JSONSchema.format_error(error)
      ~s(Invalid email format: "not-an-email")

  For compile-time schema embedding, see:

  - `Formata.JSONSchema.Schema` for the `compile!/2` macro
  - `Formata.JSONSchema.Sigil` for the `~X` sigil

  `use Formata.JSONSchema` imports the `~X` sigil as a convenience.
  """

  alias Formata.JSONSchema.Compiler
  alias Formata.JSONSchema.Validator
  alias Formata.JSONSchema.Types.{Schema, Error}

  @doc """
  Compiles a raw JSON Schema into a reusable `Schema` struct.

  ## Options

  - `:loader` — `(uri -> {:ok, map()} | {:error, term()})` for remote `$ref` schemas
  - `:base_uri` — Starting base URI for resolving relative references
  - `:format_assertion` — Explicitly enable `format` validation (default: `false`); an active Draft 2020-12 format-assertion vocabulary also enables it.
  - `:content_assertion` — Enable strict content vocabulary validation (default: `false`)
  - `:draft` — `"draft7"` or `"draft2020_12"` (strings, not atoms). Recognized root `$schema` URIs select the draft automatically; a conflicting option returns `{:error, %Formata.JSONSchema.Types.Error{rule: :draft_conflict}}`. Without either, Draft 2020-12 is the default. Custom `$schema` URIs do not select a draft.

  See the [Loader guide](guide/loader.md) and
  [Content and Format guide](guide/content_and_format.md) for details.

  ## Examples

      iex> {:ok, schema} = Formata.JSONSchema.compile(%{"type" => "string"})
      iex> is_struct(schema, Formata.JSONSchema.Types.Schema)
      true

      iex> {:ok, schema} = Formata.JSONSchema.compile(%{"type" => "string", "format" => "email"}, format_assertion: true)
      iex> Formata.JSONSchema.validate(schema, "test@example.com")
      :ok
  """
  @spec compile(map() | boolean()) :: {:ok, Schema.t()} | {:error, Error.t()}
  defdelegate compile(schema, opts \\ []), to: Compiler

  @doc """
  Compiles a JSON Schema fragment from a containing document.

  This is useful when a schema lives inside a larger resource, such as an
  OpenAPI 3.1 document, and local references like `#/components/schemas/User`
  must resolve against that containing document rather than against the fragment
  map in isolation.

  Draft 7 entry contexts follow ancestor `$id` resources: pointer lookup uses the
  owning resource's raw schema, while discovery still scans the containing document.
  Without a new resource boundary, the containing document remains the pointer root.

  ## Options

  - `:entry` — JSON Pointer or URI-reference style entrypoint (`#/...`, `/...`, or `path-or-uri#/...`). If it includes a base URI/path and `:base_uri` is omitted, that base is used for relative reference resolution.
  - `:base_uri` — optional starting base URI/path for resolving relative references when `:entry` is a document-local pointer
  - `:loader` — optional loader for external resources. It may return `{:ok, schema}` or `{:ok, %{document: schema, base_uri: base_uri}}`; wrapper metadata uses atom keys only.
  - `:format_assertion` — Explicitly enable `format` validation (default: `false`); an active Draft 2020-12 format-assertion vocabulary also enables it.
  - `:content_assertion` — Enable strict content vocabulary validation (default: `false`)
  - `:draft` — `"draft7"` or `"draft2020_12"` (strings, not atoms). A recognized `$schema` at the containing document's root selects the draft and must agree with this option. Otherwise the option selects the draft; if neither selects a draft, Draft 2020-12 is the default.

  Use a document-local entry such as `"#/components/schemas/User"` when the
  containing document's base is supplied separately with `:base_uri` or when no
  relative external refs are reachable. Use a URI-reference entry such as
  `"/api/openapi.yaml#/components/schemas/User"` when the entrypoint and base
  URI/path can be represented together.

  ## Examples

      iex> document = %{
      ...>   "components" => %{"schemas" => %{"Name" => %{"type" => "string"}}},
      ...>   "schema" => %{"$ref" => "#/components/schemas/Name"}
      ...> }
      iex> {:ok, schema} = Formata.JSONSchema.compile_fragment(document, entry: "#/schema")
      iex> Formata.JSONSchema.validate(schema, "Ada")
      :ok
      iex> {:error, [%{rule: :type}]} = Formata.JSONSchema.validate(schema, 123)

      iex> document = %{"schema" => %{"type" => "integer"}}
      iex> {:ok, schema} = Formata.JSONSchema.compile_fragment(document, entry: "/api/openapi.yaml#/schema")
      iex> Formata.JSONSchema.validate(schema, 42)
      :ok
  """
  @spec compile_fragment(map() | boolean(), keyword()) :: {:ok, Schema.t()} | {:error, Error.t()}
  defdelegate compile_fragment(document, opts), to: Compiler

  @doc """
  Bundles a JSON Schema fragment from a containing document into a standalone raw schema.

  This uses the same entrypoint and reference-context options as `compile_fragment/2`,
  follows only the schema graph reachable from the entrypoint, mounts reachable
  external resources under `$defs`, and returns a raw JSON Schema map or boolean
  that can be compiled later with `compile/2`. External refs in unrelated containing-
  document subtrees, inactive definitions, examples, and extension data are not loaded.

  ## Generated definitions

  A map bundle may contain generated entries under `$defs` whose names start with
  `jsonschex_`. These entries are required storage locations for containing-document
  context, external resources, and reachable anchors. Their exact keys are internal,
  may receive a numeric suffix to avoid a caller-owned definition, and are not a
  stable API. Resources retain their reference identity through `$id` and anchors;
  callers should compile the complete returned bundle and must not construct refs to
  generated paths such as `#/$defs/jsonschex_external_1`.

  Existing caller-owned `$defs` entries are preserved. If generated resources are
  required, an existing `$defs` value must be a map; otherwise bundling returns an
  `invalid_defs` error instead of replacing it.

  When an anchor can only be discovered through opaque containing-document data,
  a unique declaration is treated as the anchor target because Formata.JSONSchema has no
  domain-specific knowledge of containers such as OpenAPI components or extensions.
  Multiple distinct locations declaring the same anchor are reported as an
  `ambiguous_anchor` error. The loader is not invoked for any ambiguous candidate.

  ## Examples

      iex> document = %{
      ...>   "components" => %{"schemas" => %{"Name" => %{"type" => "string"}}},
      ...>   "schema" => %{"$ref" => "#/components/schemas/Name"}
      ...> }
      iex> {:ok, bundled} = Formata.JSONSchema.bundle_fragment(document, entry: "#/schema")
      iex> {:ok, schema} = Formata.JSONSchema.compile(bundled)
      iex> Formata.JSONSchema.validate(schema, "Ada")
      :ok
  """
  @spec bundle_fragment(map() | boolean(), keyword()) ::
          {:ok, map() | boolean()} | {:error, Error.t()}
  defdelegate bundle_fragment(document, opts), to: Compiler

  @doc """
  Validates data against a compiled schema.

  Returns `:ok` or `{:error, [Error.t()]}`. Use `Formata.JSONSchema.format_error/1` on
  individual errors to produce human-readable messages.

  ## Examples

      iex> {:ok, schema} = Formata.JSONSchema.compile(%{"type" => "integer"})
      iex> Formata.JSONSchema.validate(schema, 42)
      :ok

      iex> {:ok, schema} = Formata.JSONSchema.compile(%{"type" => "integer"})
      iex> {:error, errors} = Formata.JSONSchema.validate(schema, "not an integer")
      iex> [error] = errors
      iex> error.rule
      :type
      iex> error.path
      []
      iex> Formata.JSONSchema.format_error(error)
      "Expected type integer, got string"
  """
  @spec validate(Schema.t(), term()) :: :ok | {:error, list(Error.t())}
  defdelegate validate(schema, data), to: Validator

  @doc """
  Formats a validation error into a human-readable string.

  ## Examples

      iex> error = %Formata.JSONSchema.Types.Error{path: ["age", "user"], rule: :minimum, context: %Formata.JSONSchema.Types.ErrorContext{contrast: 0, input: -5}}
      iex> Formata.JSONSchema.format_error(error)
      "At /user/age: Value -5 is less than minimum 0"

      iex> {:error, error} = Formata.JSONSchema.compile(%{"type" => "1"})
      iex> Formata.JSONSchema.format_error(error)
      ~s(Keyword 'type' must be one of [string, integer, number, boolean, object, array, null], got: "1")

      iex> {:error, error} = Formata.JSONSchema.compile(%{"minimum" => "five"})
      iex> Formata.JSONSchema.format_error(error)
      ~s(Keyword 'minimum' must be a number, got: "five")

      iex> {:error, error} = Formata.JSONSchema.compile(%{"multipleOf" => -3})
      iex> Formata.JSONSchema.format_error(error)
      ~s(Keyword 'multipleOf' must be a strictly positive number, got: -3)

      iex> {:error, error} = Formata.JSONSchema.compile(%{"minLength" => -1})
      iex> Formata.JSONSchema.format_error(error)
      ~s(Keyword 'minLength' must be a non-negative integer, got: -1)

      iex> {:error, error} = Formata.JSONSchema.compile(%{"uniqueItems" => "yes"})
      iex> Formata.JSONSchema.format_error(error)
      ~s(Keyword 'uniqueItems' must be a boolean, got: "yes")
  """
  @spec format_error(Error.t()) :: String.t()
  defdelegate format_error(error), to: Formata.JSONSchema.ErrorFormatter, as: :format

  @doc """
  Imports the `~X` sigil for compile-time schema literals.

  For the explicit API, use `Formata.JSONSchema.Sigil` directly.
  """
  defmacro __using__(_opts) do
    quote do
      import Formata.JSONSchema.Sigil, only: [sigil_X: 2]
    end
  end
end
