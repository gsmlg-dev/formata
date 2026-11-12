# Regression tests for changes made in Formata's fork of backplane_schema
# 1.10.76 (not part of the upstream suite).
defmodule Formata.Vendor.BackplaneSchema.ForkFixesTest do
  use ExUnit.Case, async: true

  alias Formata.Backplane.Schema

  describe "gsmlg-opt/backplane#171: permissive mode keeps the data's keys" do
    test "updated values replace the string-keyed field instead of duplicating it" do
      assert {:ok, %{"n" => 1}} =
               Schema.validate(%{n: {:coerce, :integer}}, %{"n" => "1"}, mode: :permissive)

      assert {:ok, %{"u" => %{"n" => "a"}, "x" => 1}} ==
               Schema.validate(%{u: %{n: :string}}, %{"u" => %{"n" => "a"}, "x" => 1},
                 mode: :permissive
               )

      assert {:ok, %{"u" => %{"n" => 2}, "l" => [%{"k" => 3, "y" => 0}], "x" => 1}} ==
               Schema.validate(
                 %{u: %{n: {:coerce, :integer}}, l: {:list, %{k: {:coerce, :integer}}}},
                 %{"u" => %{"n" => "2"}, "l" => [%{"k" => "3", "y" => 0}], "x" => 1},
                 mode: :permissive
               )

      assert {:ok, %{"t" => "AB"}} ==
               Schema.validate(%{t: {:string, {:transform, &String.upcase/1}}}, %{"t" => "ab"},
                 mode: :permissive
               )
    end

    test "atom-keyed data, absent fields, and strict mode are unchanged" do
      assert {:ok, %{n: 1, x: 2}} ==
               Schema.validate(%{n: {:coerce, :integer}}, %{n: "1", x: 2}, mode: :permissive)

      # An absent field has no data key; a default is added under the schema key.
      assert {:ok, %{"x" => 1, :d => 7}} ==
               Schema.validate(%{d: {:integer, {:default, 7}}}, %{"x" => 1}, mode: :permissive)

      assert {:ok, %{n: 1}} == Schema.validate(%{n: {:coerce, :integer}}, %{"n" => "1", "x" => 2})
    end
  end
end
