defmodule Formata.NativeSchema.PerformancePhase2Test do
  use ExUnit.Case, async: true

  defmodule Record do
    defstruct [:id, :extra]
  end

  test "strict traversal preserves falsy values and applies nested conversions" do
    schema = %{
      "enabled" => {:boolean, {:default, true}},
      count: {:coerce, :string, :integer},
      note: :any,
      entries:
        {:list,
         %{
           active: :boolean,
           quantity: {:integer, {:transform, &(&1 + 1)}}
         }}
    }

    data = %{
      "enabled" => false,
      "count" => "0",
      "note" => nil,
      "entries" => [%{"active" => false, "quantity" => 1, "ignored" => true}],
      "ignored" => true
    }

    assert {:ok,
            %{
              "enabled" => false,
              count: 0,
              note: nil,
              entries: [%{active: false, quantity: 2}]
            }} = Formata.NativeSchema.decode(schema, data)

    # Formata fork (gsmlg-opt/backplane#171): upstream asserted that permissive
    # mode wrote the converted values under the atom schema keys next to the
    # original string keys (`permissive[:entries]`, `entry[:quantity]`). The
    # fork writes them under the key present in the data and never duplicates
    # a field, so the whole result is asserted instead.
    assert {:ok, permissive} = Formata.NativeSchema.decode(schema, data, mode: :permissive)

    assert permissive == %{
             "enabled" => false,
             "count" => 0,
             "note" => nil,
             "entries" => [%{"active" => false, "quantity" => 2, "ignored" => true}],
             "ignored" => true
           }
  end

  test "strict callbacks receive the unfiltered root and structs keep their fields" do
    schema = %{
      prefix: :string,
      label: {:string, {:transform, fn value, root -> root.prefix <> value end}}
    }

    assert {:ok, %{label: "raw-value"}} =
             Formata.NativeSchema.validate(schema, %{
               prefix: "raw-",
               label: "value",
               ignored: true
             })

    assert {:ok, %Record{id: 1, extra: "kept"}} =
             Formata.NativeSchema.validate(%{id: :integer}, %Record{id: 1, extra: "kept"})
  end

  test "keyword schemas preserve sequential validation for duplicate keys" do
    schema = [
      value: {:integer, {:transform, &(&1 + 1)}},
      value: {:integer, {:transform, &(&1 + 1)}}
    ]

    assert {:ok, [value: 3]} = Formata.NativeSchema.validate(schema, value: 1)
  end
end
