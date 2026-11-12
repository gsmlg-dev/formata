defmodule Formata.Vendor.BackplaneSchema.ComposeTest do
  use ExUnit.Case, async: true

  import Formata.Backplane.Schema

  doctest Formata.Backplane.Schema, only: [merge: 2, select: 2, except: 2]

  defschema(:user, %{
    name: {:required, :string},
    age: :integer
  })

  describe "merge/2" do
    test "combines disjoint fields" do
      assert {:ok, %{name: :string, age: :integer}} =
               Formata.Backplane.Schema.merge(%{name: :string}, %{age: :integer})
    end

    test "right side wins on overlapping field" do
      assert {:ok, %{name: :atom}} =
               Formata.Backplane.Schema.merge(%{name: :string}, %{name: :atom})
    end

    test "deep merges nested maps preserving fields from both sides" do
      left = %{user: %{name: :string, profile: %{bio: :string}}}
      right = %{user: %{age: :integer, profile: %{avatar: :string}}}

      assert {:ok,
              %{
                user: %{
                  name: :string,
                  age: :integer,
                  profile: %{bio: :string, avatar: :string}
                }
              }} = Formata.Backplane.Schema.merge(left, right)
    end

    test "right side wins on conflicting nested leaf" do
      left = %{user: %{name: :string}}
      right = %{user: %{name: {:required, :string}}}

      assert {:ok, %{user: %{name: {:required, :string}}}} =
               Formata.Backplane.Schema.merge(left, right)
    end

    test "type tuples are never merged structurally" do
      left = %{tags: {:list, :string}}
      right = %{tags: {:list, :integer}}

      assert {:ok, %{tags: {:list, :integer}}} = Formata.Backplane.Schema.merge(left, right)
    end

    test "merged schema validates data correctly" do
      {:ok, base} =
        Formata.Backplane.Schema.merge(%{name: {:required, :string}}, %{age: :integer})

      {:ok, schema} = Formata.Backplane.Schema.merge(base, %{admin: :boolean})

      assert {:ok, %{name: "Zoey", age: 30, admin: true}} =
               Formata.Backplane.Schema.validate(schema, %{name: "Zoey", age: 30, admin: true})

      assert {:error, _} = Formata.Backplane.Schema.validate(schema, %{age: 30})
    end

    test "round-trips a defschema through merge" do
      {:ok, extended} =
        Formata.Backplane.Schema.merge(get_schema(:user), %{role: {:enum, [:admin, :member]}})

      data = %{name: "Zoey", age: 30, role: :admin}
      assert {:ok, ^data} = Formata.Backplane.Schema.validate(extended, data)

      assert {:error, _} =
               Formata.Backplane.Schema.validate(extended, %{name: "Zoey", role: :root})
    end

    test "returns error when the merged result is invalid" do
      assert {:error, _} = Formata.Backplane.Schema.merge(%{name: :string}, %{age: :str})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.Backplane.Schema.merge(:string, %{}) end
      assert_raise ArgumentError, fn -> Formata.Backplane.Schema.merge(%{}, :string) end
    end
  end

  describe "select/2" do
    test "keeps only the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, email: :string}} =
               Formata.Backplane.Schema.select(schema, [:name, :email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} =
               Formata.Backplane.Schema.select(%{name: :string}, [:name, :missing])
    end

    test "empty selection returns an empty schema" do
      assert {:ok, schema} = Formata.Backplane.Schema.select(%{name: :string}, [])
      assert map_size(schema) == 0
    end

    test "selected schema validates data correctly" do
      {:ok, public} =
        Formata.Backplane.Schema.select(%{name: :string, password: :string}, [:name])

      assert {:ok, %{name: "Zoey"}} =
               Formata.Backplane.Schema.validate(public, %{name: "Zoey", password: "secret"})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.Backplane.Schema.select(:string, [:name]) end
    end
  end

  describe "except/2" do
    test "drops the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, age: :integer}} =
               Formata.Backplane.Schema.except(schema, [:email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} =
               Formata.Backplane.Schema.except(%{name: :string}, [:missing])
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.Backplane.Schema.except(:string, [:name]) end
    end
  end
end
