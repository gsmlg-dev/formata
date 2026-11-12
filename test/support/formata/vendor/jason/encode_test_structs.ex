# Struct fixtures for Formata.Vendor.JasonEncoderTest (ported from jason 1.4.5
# test/encode_test.exs). Compiled with test/support so the derived and explicit
# Formata.Jason.Encoder implementations are part of the consolidated protocol.

defmodule Formata.Vendor.JasonEncoderTest.Derived do
  @derive Formata.Jason.Encoder
  defstruct name: ""
end

defmodule Formata.Vendor.JasonEncoderTest.DerivedUsingOnly do
  @derive {Formata.Jason.Encoder, only: [:name]}
  defstruct name: "", size: 0
end

defmodule Formata.Vendor.JasonEncoderTest.DerivedUsingExcept do
  @derive {Formata.Jason.Encoder, except: [:name]}
  defstruct name: "", size: 0
end

defmodule Formata.Vendor.JasonEncoderTest.DerivedWeirdKey do
  @derive Formata.Jason.Encoder
  defstruct [:_]
end

defmodule Formata.Vendor.JasonEncoderTest.NonDerived do
  defstruct name: ""
end

defmodule Formata.Vendor.JasonEncoderTest.KeywordTester do
  defstruct [:baz, :foo, :quux]
end

defimpl Formata.Jason.Encoder, for: [Formata.Vendor.JasonEncoderTest.KeywordTester] do
  def encode(struct, opts) do
    struct
    |> Map.from_struct()
    |> Enum.sort_by(&elem(&1, 0))
    |> Formata.Jason.Encode.keyword(opts)
  end
end
