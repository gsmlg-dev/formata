defmodule Formata.YAML.Writer.EncoderTest do
  use ExUnit.Case

  test "No errors for correct struct definitions" do
    defmodule TestStruct do
      defstruct [:foo, :bar]
    end

    defmodule TestStructDerivedAll do
      @derive Formata.YAML.Writer.Encoder
      defstruct [:foo, :bar]
    end

    defmodule TestStructDerivedOnlyFoo do
      @derive {Formata.YAML.Writer.Encoder, only: [:foo]}
      defstruct [:foo, :bar]
    end

    defmodule TestStructDerivedExceptFoo do
      @derive {Formata.YAML.Writer.Encoder, except: [:foo]}
      defstruct [:foo, :bar]
    end

    defmodule TestStructDerivedExceptDefaults do
      @derive {Formata.YAML.Writer.Encoder, except: :defaults}
      defstruct [:foo, bar: 1, baz: :ok]
    end
  end

  test "Raises if fields don't exist" do
    assert_raise ArgumentError, ~r/not defined in defstruct/, fn ->
      defmodule TestStructDerivedExceptRaises do
        @derive {Formata.YAML.Writer.Encoder, except: [:inexistent]}
        defstruct [:foo, :bar]
      end
    end

    assert_raise ArgumentError, ~r/not defined in defstruct/, fn ->
      defmodule TestStructDerivedOnlyRaises do
        @derive {Formata.YAML.Writer.Encoder, only: [:inexistent]}
        defstruct [:foo, :bar]
      end
    end
  end
end
