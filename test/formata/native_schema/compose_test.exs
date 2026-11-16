defmodule Formata.NativeSchema.ComposeTest do
  use ExUnit.Case, async: true

  import Formata.NativeSchema

  doctest Formata.NativeSchema, only: [merge: 2, select: 2, except: 2]

  defschema(:user, %{
    name: {:required, :string},
    age: :integer
  })

  describe "merge/2" do
    test "combines disjoint fields" do
      assert {:ok, %{name: :string, age: :integer}} =
               Formata.NativeSchema.merge(%{name: :string}, %{age: :integer})
    end

    test "right side wins on overlapping field" do
      assert {:ok, %{name: :atom}} =
               Formata.NativeSchema.merge(%{name: :string}, %{name: :atom})
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
              }} = Formata.NativeSchema.merge(left, right)
    end

    test "right side wins on conflicting nested leaf" do
      left = %{user: %{name: :string}}
      right = %{user: %{name: {:required, :string}}}

      assert {:ok, %{user: %{name: {:required, :string}}}} =
               Formata.NativeSchema.merge(left, right)
    end

    test "type tuples are never merged structurally" do
      left = %{tags: {:list, :string}}
      right = %{tags: {:list, :integer}}

      assert {:ok, %{tags: {:list, :integer}}} = Formata.NativeSchema.merge(left, right)
    end

    test "merged schema validates data correctly" do
      {:ok, base} =
        Formata.NativeSchema.merge(%{name: {:required, :string}}, %{age: :integer})

      {:ok, schema} = Formata.NativeSchema.merge(base, %{admin: :boolean})

      assert {:ok, %{name: "Zoey", age: 30, admin: true}} =
               Formata.NativeSchema.validate(schema, %{name: "Zoey", age: 30, admin: true})

      assert {:error, _} = Formata.NativeSchema.validate(schema, %{age: 30})
    end

    test "round-trips a defschema through merge" do
      {:ok, extended} =
        Formata.NativeSchema.merge(get_schema(:user), %{role: {:enum, [:admin, :member]}})

      data = %{name: "Zoey", age: 30, role: :admin}
      assert {:ok, ^data} = Formata.NativeSchema.validate(extended, data)

      assert {:error, _} =
               Formata.NativeSchema.validate(extended, %{name: "Zoey", role: :root})
    end

    test "returns error when the merged result is invalid" do
      assert {:error, _} = Formata.NativeSchema.merge(%{name: :string}, %{age: :str})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.NativeSchema.merge(:string, %{}) end
      assert_raise ArgumentError, fn -> Formata.NativeSchema.merge(%{}, :string) end
    end
  end

  describe "select/2" do
    test "keeps only the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, email: :string}} =
               Formata.NativeSchema.select(schema, [:name, :email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} =
               Formata.NativeSchema.select(%{name: :string}, [:name, :missing])
    end

    test "empty selection returns an empty schema" do
      assert {:ok, schema} = Formata.NativeSchema.select(%{name: :string}, [])
      assert map_size(schema) == 0
    end

    test "selected schema validates data correctly" do
      {:ok, public} =
        Formata.NativeSchema.select(%{name: :string, password: :string}, [:name])

      assert {:ok, %{name: "Zoey"}} =
               Formata.NativeSchema.validate(public, %{name: "Zoey", password: "secret"})
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.NativeSchema.select(:string, [:name]) end
    end
  end

  describe "except/2" do
    test "drops the given keys" do
      schema = %{name: :string, age: :integer, email: :string}

      assert {:ok, %{name: :string, age: :integer}} =
               Formata.NativeSchema.except(schema, [:email])
    end

    test "ignores keys not present in the schema" do
      assert {:ok, %{name: :string}} =
               Formata.NativeSchema.except(%{name: :string}, [:missing])
    end

    test "raises ArgumentError on non-map schemas" do
      assert_raise ArgumentError, fn -> Formata.NativeSchema.except(:string, [:name]) end
    end
  end
end
