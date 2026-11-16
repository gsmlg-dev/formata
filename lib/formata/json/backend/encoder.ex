defprotocol Formata.JSON.Backend.Encoder do
  @moduledoc """
  Protocol controlling how a value is encoded to JSON.

  ## Deriving

  The protocol allows leveraging the Elixir's `@derive` feature
  to simplify protocol implementation in trivial cases. Accepted
  options are:

    * `:only` - encodes only values of specified keys.
    * `:except` - encodes all struct fields except specified keys.

  By default all keys except the `:__struct__` key are encoded.

  ## Example

  Let's assume a presence of the following struct:

      defmodule Test do
        defstruct [:foo, :bar, :baz]
      end

  If we were to call `@derive Formata.JSON.Backend.Encoder` just before `defstruct`,
  an implementation similar to the following implementation would be generated:

      defimpl Formata.JSON.Backend.Encoder, for: Test do
        def encode(value, opts) do
          Formata.JSON.Backend.Encode.map(Map.take(value, [:foo, :bar, :baz]), opts)
        end
      end

  If we called `@derive {Formata.JSON.Backend.Encoder, only: [:foo]}`, an implementation
  similar to the following implementation would be generated:

      defimpl Formata.JSON.Backend.Encoder, for: Test do
        def encode(value, opts) do
          Formata.JSON.Backend.Encode.map(Map.take(value, [:foo]), opts)
        end
      end

  If we called `@derive {Formata.JSON.Backend.Encoder, except: [:foo]}`, an implementation
  similar to the following implementation would be generated:

      defimpl Formata.JSON.Backend.Encoder, for: Test do
        def encode(value, opts) do
          Formata.JSON.Backend.Encode.map(Map.take(value, [:bar, :baz]), opts)
        end
      end

  The actually generated implementations are more efficient computing some data
  during compilation similar to the macros from the `Formata.JSON.Backend.Helpers` module.

  ## Explicit implementation

  If you wish to implement the protocol fully yourself, it is advised to
  use functions from the `Formata.JSON.Backend.Encode` module to do the actual iodata
  generation - they are highly optimized and verified to always produce
  valid JSON.
  """

  @type t :: term
  @type opts :: Formata.JSON.Backend.Encode.opts()

  @fallback_to_any true

  @doc """
  Encodes `value` to JSON.

  The argument `opts` is opaque - it can be passed to various functions in
  `Formata.JSON.Backend.Encode` (or to the protocol function itself) for encoding values to JSON.
  """
  @spec encode(t, opts) :: iodata
  def encode(value, opts)
end

defimpl Formata.JSON.Backend.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)
    kv = Enum.map(fields, &{&1, generated_var(&1)})
    escape = quote(do: escape)
    encode_map = quote(do: encode_map)
    encode_args = [escape, encode_map]
    kv_iodata = Formata.JSON.Backend.Codegen.build_kv_iodata(kv, encode_args)

    quote do
      defimpl Formata.JSON.Backend.Encoder, for: unquote(module) do
        require Formata.JSON.Backend.Helpers

        def encode(%{unquote_splicing(kv)}, {unquote(escape), unquote(encode_map)}) do
          unquote(kv_iodata)
        end
      end
    end
  end

  # The same as Macro.var/2 except it sets generated: true and handles _ key
  defp generated_var(:_) do
    {:__, [generated: true], __MODULE__.Underscore}
  end

  defp generated_var(name) do
    {name, [generated: true], __MODULE__}
  end

  def encode(%_{} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      Formata.JSON.Backend.Encoder protocol must always be explicitly implemented.

      If you own the struct, you can derive the implementation specifying \
      which fields should be encoded to JSON:

          @derive {Formata.JSON.Backend.Encoder, only: [....]}
          defstruct ...

      It is also possible to encode all fields, although this should be \
      used carefully to avoid accidentally leaking private information \
      when new fields are added:

          @derive Formata.JSON.Backend.Encoder
          defstruct ...

      Finally, if you don't own the struct you want to encode to JSON, \
      you may use Protocol.derive/3 placed outside of any module:

          Protocol.derive(Formata.JSON.Backend.Encoder, NameOfTheStruct, only: [...])
          Protocol.derive(Formata.JSON.Backend.Encoder, NameOfTheStruct)
      """
  end

  def encode(value, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: value,
      description: "Formata.JSON.Backend.Encoder protocol must always be explicitly implemented"
  end

  defp fields_to_encode(struct, opts) do
    fields = Map.keys(struct)

    cond do
      only = Keyword.get(opts, :only) ->
        case only -- fields do
          [] ->
            only

          error_keys ->
            raise ArgumentError,
                  "`:only` specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      except = Keyword.get(opts, :except) ->
        case except -- fields do
          [] ->
            fields -- [:__struct__ | except]

          error_keys ->
            raise ArgumentError,
                  "`:except` specified keys (#{inspect(error_keys)}) that are not defined in defstruct: " <>
                    "#{inspect(fields -- [:__struct__])}"
        end

      true ->
        fields -- [:__struct__]
    end
  end
end

# The following implementations are formality - they are already covered
# by the main encoding mechanism in Formata.JSON.Backend.Encode, but exist mostly for
# documentation purposes and if anybody had the idea to call the protocol directly.

defimpl Formata.JSON.Backend.Encoder, for: Atom do
  def encode(atom, opts) do
    Formata.JSON.Backend.Encode.atom(atom, opts)
  end
end

defimpl Formata.JSON.Backend.Encoder, for: Integer do
  def encode(integer, _opts) do
    Formata.JSON.Backend.Encode.integer(integer)
  end
end

defimpl Formata.JSON.Backend.Encoder, for: Float do
  def encode(float, _opts) do
    Formata.JSON.Backend.Encode.float(float)
  end
end

defimpl Formata.JSON.Backend.Encoder, for: List do
  def encode(list, opts) do
    Formata.JSON.Backend.Encode.list(list, opts)
  end
end

defimpl Formata.JSON.Backend.Encoder, for: Map do
  def encode(map, opts) do
    Formata.JSON.Backend.Encode.map(map, opts)
  end
end

defimpl Formata.JSON.Backend.Encoder, for: BitString do
  def encode(binary, opts) when is_binary(binary) do
    Formata.JSON.Backend.Encode.string(binary, opts)
  end

  def encode(bitstring, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot encode a bitstring to JSON"
  end
end

defimpl Formata.JSON.Backend.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  def encode(value, _opts) do
    [?", @for.to_iso8601(value), ?"]
  end
end

defimpl Formata.JSON.Backend.Encoder, for: Formata.JSON.Backend.Fragment do
  def encode(%{encode: encode}, opts) do
    encode.(opts)
  end
end
