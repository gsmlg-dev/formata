defmodule Formata.JSON.OrderedObjectTest do
  use ExUnit.Case, async: true

  alias Formata.JSON.OrderedObject

  doctest Formata.JSON.OrderedObject

  test "JSON.Encoder preserves pair order and checks encoded key collisions" do
    assert Formata.JSON.encode!(OrderedObject.new([{"z", :ok}, {1, [true]}, {:a, nil}])) ==
             ~s({"z":"ok","1":[true],"a":null})

    for pairs <- [[{"a", 1}, {"a", 2}], [{:a, 1}, {"a", 2}], [{1, 1}, {"1", 2}]],
        pretty <- [false, true] do
      error =
        assert_raise ErlangError, fn ->
          Formata.JSON.encode!(OrderedObject.new(pairs), pretty: pretty)
        end

      assert {:duplicate_key, _key} = error.original
    end
  end

  test "adding and removing a configuration field preserves unrelated order" do
    object = OrderedObject.new(for n <- 40..1//-1, do: {"key#{n}", n})
    assert put_in(object["installed"], true)["installed"] == true
    assert {true, restored} = pop_in(put_in(object["installed"], true)["installed"])
    assert restored == object

    assert Formata.JSON.decode!(Formata.JSON.encode!(restored), objects: :ordered_objects) ==
             object
  end

  test "Access behavior" do
    obj = OrderedObject.new([{:foo, 1}, {"bar", 2}])

    assert obj[:foo] == 1
    assert obj["bar"] == 2

    assert Access.pop(obj, :foo) == {1, OrderedObject.new([{"bar", 2}])}

    obj = OrderedObject.new(foo: OrderedObject.new(bar: 1))
    assert obj[:foo][:bar] == 1
    modified_obj = put_in(obj[:foo][:bar], 2)
    assert %OrderedObject{} = modified_obj[:foo]
    assert modified_obj[:foo][:bar] == 2
  end

  test "Enumerable protocol" do
    obj = OrderedObject.new(foo: 1, bar: 2, quux: 42)

    assert Enum.count(obj) == 3
    assert Enum.member?(obj, {:foo, 1})

    assert Enum.into(obj, %{}) == %{foo: 1, bar: 2, quux: 42}
    assert Enum.into(obj, []) == [foo: 1, bar: 2, quux: 42]
  end
end
