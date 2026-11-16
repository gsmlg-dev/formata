defmodule Formata.NativeSchema.HumanizeTest do
  use ExUnit.Case, async: true

  import Formata.NativeSchema

  doctest Formata.NativeSchema.Error, only: [humanize: 1]

  defschema(:account, %{
    email: {:required, :string},
    name: :string
  })

  defschema(:profile_user, %{
    user: %{
      profile: %{
        age: {:required, :integer}
      }
    }
  })

  defschema(:constrained, %{
    name: {:string, [{:min, 5}, {:regex, ~r/^a/}]}
  })

  describe "humanize/1" do
    test "empty list returns an empty map" do
      assert Formata.NativeSchema.Error.humanize([]) == %{}
    end

    test "flat errors map fields to message lists" do
      assert {:error, errors} = account(%{name: "Jane"})

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               email: ["is required, expected type of :string"]
             }
    end

    test "string path segments stay strings" do
      assert {:error, errors} = account(%{"name" => "Jane"})

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               email: ["is required, expected type of :string"]
             }
    end

    test "nested schemas produce nested maps" do
      assert {:error, errors} = profile_user(%{user: %{profile: %{}}})

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               user: %{profile: %{age: ["is required, expected type of :integer"]}}
             }
    end

    test "integer path segments become integer keys" do
      errors = [
        %Formata.NativeSchema.Error{
          path: [:addresses],
          key: :addresses,
          errors: [
            %Formata.NativeSchema.Error{
              path: [:addresses, 0, :street],
              key: :street,
              message: "is too short"
            }
          ]
        }
      ]

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               addresses: %{0 => %{street: ["is too short"]}}
             }
    end

    test "scalar list failures humanize under their zero-based index" do
      assert {:error, errors} =
               Formata.NativeSchema.validate(%{scores: {:list, :integer}}, %{scores: [1, "x"]})

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               scores: %{1 => ["expected type of :integer received \"x\" value"]}
             }
    end

    test "multiple leaf errors at the same path append messages" do
      assert {:error, errors} = constrained(%{name: "bbb"})

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               name: ["should match the ~r/^a/ pattern", "should have the minimum length of 5"]
             }
    end

    test "parent errors contribute only through their children" do
      parent = %Formata.NativeSchema.Error{
        path: [:user],
        key: :user,
        errors: [
          %Formata.NativeSchema.Error{path: [:user, :age], key: :age, message: "is invalid"},
          %Formata.NativeSchema.Error{
            path: [:user, :age],
            key: :age,
            message: "is suspicious"
          }
        ]
      }

      assert Formata.NativeSchema.Error.humanize(parent) == %{
               user: %{age: ["is invalid", "is suspicious"]}
             }
    end

    test "prefix-colliding paths keep both messages and nested entries" do
      errors = [
        %Formata.NativeSchema.Error{path: [:user], key: :user, message: "is invalid"},
        %Formata.NativeSchema.Error{path: [:user, :age], key: :age, message: "is required"}
      ]

      assert Formata.NativeSchema.Error.humanize(errors) == %{
               user: %{_: ["is invalid"], age: ["is required"]}
             }

      assert Formata.NativeSchema.Error.humanize(Enum.reverse(errors)) ==
               %{user: %{_: ["is invalid"], age: ["is required"]}}
    end

    test "pathless errors from new_single humanize to a bare message list" do
      assert {:error, error} = Formata.NativeSchema.validate(:string, 5)

      assert Formata.NativeSchema.Error.humanize(error) == [
               "expected type of :string received 5 value"
             ]
    end

    test "composes with traverse_errors/2 for translated messages" do
      assert {:error, errors} = profile_user(%{user: %{profile: %{}}})

      translated =
        Formata.NativeSchema.Error.traverse_errors(errors, fn err ->
          "translated: #{err.message}"
        end)

      assert Formata.NativeSchema.Error.humanize(translated) == %{
               user: %{
                 profile: %{age: ["translated: is required, expected type of :integer"]}
               }
             }
    end
  end

  describe "missing required key spellcheck" do
    test "suggests a typo'd atom key present in the data" do
      assert {:error, [%Formata.NativeSchema.Error{} = err]} =
               account(%{emial: "jane@example.com"})

      assert err.message == "is required, expected type of :string did you mean :emial?"
      assert err.content[:did_you_mean] == :emial
    end

    test "suggests a typo'd string key present in the data" do
      assert {:error, [%Formata.NativeSchema.Error{} = err]} =
               account(%{"emial" => "jane@example.com"})

      assert err.message == "is required, expected type of :string did you mean emial?"
      assert err.content[:did_you_mean] == "emial"
    end

    test "no suggestion when no key is close enough" do
      assert {:error, [%Formata.NativeSchema.Error{} = err]} = account(%{zzz: 1})

      assert err.message == "is required, expected type of :string"
      refute Map.has_key?(err.content, :did_you_mean)
    end

    test "suggests keys inside nested schemas" do
      assert {:error, [%Formata.NativeSchema.Error{errors: [nested]}]} =
               Formata.NativeSchema.validate(%{user: %{email: {:required, :string}}}, %{
                 user: %{emial: "x"}
               })

      assert nested.message == "is required, expected type of :string did you mean :emial?"
      assert nested.content[:did_you_mean] == :emial
    end

    test "suggests keys inside list elements" do
      schema = %{users: {:list, %{email: {:required, :string}}}}

      assert {:error, [%Formata.NativeSchema.Error{errors: [nested]}]} =
               Formata.NativeSchema.validate(schema, %{users: [%{emial: "x"}]})

      assert nested.content[:did_you_mean] == :emial
    end

    test "also applies in permissive mode" do
      assert {:error, [%Formata.NativeSchema.Error{} = err]} =
               Formata.NativeSchema.validate(get_schema(:account), %{emial: "x"},
                 mode: :permissive
               )

      assert err.content[:did_you_mean] == :emial
    end

    test "custom error override still wins over the suggestion" do
      schema = %{email: {:required, :string, error: "we need your email"}}

      assert {:error, [%Formata.NativeSchema.Error{} = err]} =
               Formata.NativeSchema.validate(schema, %{emial: "x"})

      assert err.message == "we need your email"
      assert err.content[:did_you_mean] == :emial
    end

    test "ignores keys that are neither atoms nor strings" do
      assert {:ok, _} =
               Formata.NativeSchema.validate(%{}, %{self() => :a, [false] => :b, {} => :c})

      assert {:error, [%Formata.NativeSchema.Error{} = err]} =
               Formata.NativeSchema.validate(%{email: {:required, :string}}, %{self() => :a})

      refute Map.has_key?(err.content, :did_you_mean)
    end
  end
end
