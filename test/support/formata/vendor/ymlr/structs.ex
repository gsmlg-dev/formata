defmodule Formata.Vendor.Ymlr.TestStruct do
  defstruct [:foo, :bar]
end

defmodule Formata.Vendor.Ymlr.TestStructDerivedAll do
  @derive Formata.Ymlr.Encoder
  defstruct [:foo, :bar]
end

defmodule Formata.Vendor.Ymlr.TestStructDerivedOnlyFoo do
  @derive {Formata.Ymlr.Encoder, only: [:foo]}
  defstruct [:foo, :bar]
end

defmodule Formata.Vendor.Ymlr.TestStructDerivedExceptFoo do
  @derive {Formata.Ymlr.Encoder, except: [:foo]}
  defstruct [:foo, :bar]
end

defmodule Formata.Vendor.Ymlr.TestStructDerivedExceptDefaults do
  @derive {Formata.Ymlr.Encoder, except: :defaults}
  @enforce_keys [:foo]
  defstruct [:foo, bar: 1, baz: :ok]
end
