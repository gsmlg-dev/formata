defmodule Formata.NativeSchema.CustomErrorsTest do
  use ExUnit.Case, async: true

  import Formata.NativeSchema

  defmodule Msgs do
    def email_msg(%Formata.NativeSchema.Error{} = err),
      do: "email is invalid (was: #{inspect(err.content)})"

    def with_args(%Formata.NativeSchema.Error{}, prefix), do: "#{prefix}: bad value"
  end

  defschema(:user, %{
    age: {:integer, gte: 18, error: "must be adult"},
    email: {:required, :string, [error: {Msgs, :email_msg, []}]},
    nickname: {:string, [min: 3, error: "too short"]}
  })

  describe "field-level error overrides" do
    test "static string overrides constraint error" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:age], message: "must be adult"}]} =
               user(%{age: 10, email: "a@b.io"})
    end

    test "MFA override receives the Formata.NativeSchema.Error and returns string" do
      assert {:error, errors} = user(%{email: 123})
      err = Enum.find(errors, &(&1.key == :email))
      assert err
      assert is_binary(err.message)
      assert err.message =~ "email is invalid"
      assert err.message =~ "(was: "
    end

    test "MFA override fires when required field is missing" do
      assert {:error, errors} = user(%{age: 20})
      err = Enum.find(errors, &(&1.key == :email))
      assert err.message =~ "email is invalid"
    end

    test "static string override on nested string constraint" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:nickname], message: "too short"}]} =
               user(%{age: 20, email: "a@b.io", nickname: "ab"})
    end

    test "no override means default message" do
      schema = %{age: {:integer, gte: 18}}

      assert {:error, [%Formata.NativeSchema.Error{path: [:age], message: msg}]} =
               Formata.NativeSchema.validate(schema, %{age: 5})

      refute msg == "must be adult"
    end
  end

  describe "validate_schema" do
    test "rejects non-string non-MFA error opt" do
      schema = %{x: {:integer, [error: 123]}}
      assert {:error, _} = Formata.NativeSchema.validate_schema(schema)
    end

    test "accepts static string" do
      schema = %{x: {:integer, [error: "bad"]}}
      assert {:ok, ^schema} = Formata.NativeSchema.validate_schema(schema)
    end

    test "accepts MFA" do
      schema = %{x: {:integer, [error: {Mod, :fun, []}]}}
      assert {:ok, ^schema} = Formata.NativeSchema.validate_schema(schema)
    end

    test "{:required, type, [error: msg]} valid" do
      schema = %{x: {:required, :string, [error: "needed"]}}
      assert {:ok, ^schema} = Formata.NativeSchema.validate_schema(schema)
    end
  end

  describe "Formata.NativeSchema.Error.traverse_errors/2" do
    test "translates flat errors" do
      {:error, errors} = user(%{age: 10, email: "a@b.io"})

      translated =
        Formata.NativeSchema.Error.traverse_errors(errors, fn err ->
          "[translated] #{err.message}"
        end)

      assert Enum.all?(translated, fn err -> String.starts_with?(err.message, "[translated]") end)
    end

    test "translates nested errors at leaves" do
      schema = %{outer: %{inner: {:required, :string, [error: "leaf-msg"]}}}
      {:error, errors} = Formata.NativeSchema.validate(schema, %{outer: %{}})

      translated =
        Formata.NativeSchema.Error.traverse_errors(errors, fn err ->
          "x_" <> err.message
        end)

      [%Formata.NativeSchema.Error{errors: [leaf]}] = translated
      assert leaf.message == "x_leaf-msg"
    end

    test "non-string callback result coerces to string" do
      {:error, errors} = user(%{age: 10, email: "a@b.io"})
      translated = Formata.NativeSchema.Error.traverse_errors(errors, fn _ -> :ok end)
      assert Enum.all?(translated, fn err -> err.message == "ok" end)
    end
  end

  describe "Formata.NativeSchema.Error.error_to_map/1" do
    test "keeps nil content without raising" do
      error = %Formata.NativeSchema.Error{
        message: "Expected type string, got integer",
        content: nil,
        path: [:user, :age],
        key: :age,
        errors: nil
      }

      assert %{
               message: "Expected type string, got integer",
               content: nil,
               path: [:user, :age],
               key: :age,
               errors: nil
             } = Formata.NativeSchema.Error.error_to_map(error)
    end

    test "keeps nil content in nested errors without raising" do
      error = %Formata.NativeSchema.Error{
        message: "Validation failed",
        content: %{expected: :string, actual: :integer},
        path: [:user, :age],
        key: :age,
        errors: [
          %Formata.NativeSchema.Error{
            message: "Expected type string, got integer",
            content: nil,
            path: [:user, :age],
            key: :age,
            errors: nil
          }
        ]
      }

      assert %{
               content: %{expected: :string, actual: :integer},
               errors: [
                 %{
                   message: "Expected type string, got integer",
                   content: nil,
                   path: [:user, :age],
                   key: :age,
                   errors: nil
                 }
               ]
             } = Formata.NativeSchema.Error.error_to_map(error)
    end

    test "still transforms tuple content inside map and keyword content" do
      map_error = %Formata.NativeSchema.Error{
        content: %{schema: {:list, {:tuple, [:string, :integer]}}}
      }

      keyword_error = %Formata.NativeSchema.Error{content: [schema: {:list, :string}]}

      assert %{content: %{schema: [:list, [:tuple, [:string, :integer]]]}} =
               Formata.NativeSchema.Error.error_to_map(map_error)

      assert %{content: %{schema: [:list, :string]}} =
               Formata.NativeSchema.Error.error_to_map(keyword_error)
    end

    test "keeps non-keyword list content unchanged" do
      error = %Formata.NativeSchema.Error{content: [1, 2, 3]}

      assert %{content: [1, 2, 3]} = Formata.NativeSchema.Error.error_to_map(error)
    end
  end
end
