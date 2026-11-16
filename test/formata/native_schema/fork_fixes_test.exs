# Regression tests for changes made in Formata's fork of backplane_schema
# 1.10.76 (not part of the upstream suite).
defmodule Formata.NativeSchema.ForkFixesTest do
  use ExUnit.Case, async: true

  alias Formata.NativeSchema

  describe "gsmlg-opt/backplane#171: permissive mode keeps the data's keys" do
    test "updated values replace the string-keyed field instead of duplicating it" do
      assert {:ok, %{"n" => 1}} =
               NativeSchema.validate(%{n: {:coerce, :integer}}, %{"n" => "1"}, mode: :permissive)

      assert {:ok, %{"u" => %{"n" => "a"}, "x" => 1}} ==
               NativeSchema.validate(%{u: %{n: :string}}, %{"u" => %{"n" => "a"}, "x" => 1},
                 mode: :permissive
               )

      assert {:ok, %{"u" => %{"n" => 2}, "l" => [%{"k" => 3, "y" => 0}], "x" => 1}} ==
               NativeSchema.validate(
                 %{u: %{n: {:coerce, :integer}}, l: {:list, %{k: {:coerce, :integer}}}},
                 %{"u" => %{"n" => "2"}, "l" => [%{"k" => "3", "y" => 0}], "x" => 1},
                 mode: :permissive
               )

      assert {:ok, %{"t" => "AB"}} ==
               NativeSchema.validate(
                 %{t: {:string, {:transform, &String.upcase/1}}},
                 %{"t" => "ab"},
                 mode: :permissive
               )
    end

    test "atom-keyed data, absent fields, and strict mode are unchanged" do
      assert {:ok, %{n: 1, x: 2}} ==
               NativeSchema.validate(%{n: {:coerce, :integer}}, %{n: "1", x: 2},
                 mode: :permissive
               )

      # An absent field has no data key; a default is added under the schema key.
      assert {:ok, %{"x" => 1, :d => 7}} ==
               NativeSchema.validate(%{d: {:integer, {:default, 7}}}, %{"x" => 1},
                 mode: :permissive
               )

      assert {:ok, %{n: 1}} ==
               NativeSchema.validate(%{n: {:coerce, :integer}}, %{"n" => "1", "x" => 2})
    end
  end
end
