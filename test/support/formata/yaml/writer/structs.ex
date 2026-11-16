defmodule Formata.YAML.Writer.TestStruct do
  defstruct [:foo, :bar]
end

defmodule Formata.YAML.Writer.TestStructDerivedAll do
  @derive Formata.YAML.Writer.Encoder
  defstruct [:foo, :bar]
end

defmodule Formata.YAML.Writer.TestStructDerivedOnlyFoo do
  @derive {Formata.YAML.Writer.Encoder, only: [:foo]}
  defstruct [:foo, :bar]
end

defmodule Formata.YAML.Writer.TestStructDerivedExceptFoo do
  @derive {Formata.YAML.Writer.Encoder, except: [:foo]}
  defstruct [:foo, :bar]
end

defmodule Formata.YAML.Writer.TestStructDerivedExceptDefaults do
  @derive {Formata.YAML.Writer.Encoder, except: :defaults}
  @enforce_keys [:foo]
  defstruct [:foo, bar: 1, baz: :ok]
end
