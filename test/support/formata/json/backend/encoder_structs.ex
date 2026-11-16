# Struct fixtures for Formata.JSON.Backend.EncoderTest (ported from jason 1.4.5
# test/encode_test.exs). Compiled with test/support so the derived and explicit
# Formata.JSON.Backend.Encoder implementations are part of the consolidated protocol.

defmodule Formata.JSON.Backend.EncoderTest.Derived do
  @derive Formata.JSON.Backend.Encoder
  defstruct name: ""
end

defmodule Formata.JSON.Backend.EncoderTest.DerivedUsingOnly do
  @derive {Formata.JSON.Backend.Encoder, only: [:name]}
  defstruct name: "", size: 0
end

defmodule Formata.JSON.Backend.EncoderTest.DerivedUsingExcept do
  @derive {Formata.JSON.Backend.Encoder, except: [:name]}
  defstruct name: "", size: 0
end

defmodule Formata.JSON.Backend.EncoderTest.DerivedWeirdKey do
  @derive Formata.JSON.Backend.Encoder
  defstruct [:_]
end

defmodule Formata.JSON.Backend.EncoderTest.NonDerived do
  defstruct name: ""
end

defmodule Formata.JSON.Backend.EncoderTest.KeywordTester do
  defstruct [:baz, :foo, :quux]
end

defimpl Formata.JSON.Backend.Encoder, for: [Formata.JSON.Backend.EncoderTest.KeywordTester] do
  def encode(struct, opts) do
    struct
    |> Map.from_struct()
    |> Enum.sort_by(&elem(&1, 0))
    |> Formata.JSON.Backend.Encode.keyword(opts)
  end
end
