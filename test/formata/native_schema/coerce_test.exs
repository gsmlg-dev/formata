defmodule Formata.NativeSchema.CoerceTest.CustomCoercions do
  @moduledoc false

  def parse_amount(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int * 100}
      _other -> :error
    end
  end

  def parse_amount(_val), do: :error

  def parse_with_args(val, factor) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int * factor}
      _other -> :error
    end
  end

  def parse_with_args(_val, _factor), do: :error
end

defmodule Formata.NativeSchema.CoerceTest do
  use ExUnit.Case, async: true

  import Formata.NativeSchema

  doctest Formata.NativeSchema, only: [decode: 3, encode: 3]

  alias Formata.NativeSchema.CoerceTest.CustomCoercions

  defschema(:pagination, %{
    page: {:coerce, :string, :integer},
    per_page: {:coerce, :string, :integer},
    active: {:coerce, :string, :boolean}
  })

  defschema(:wire_params, %{
    "page" => {:coerce, :string, :integer},
    "since" => {:coerce, :string, :date}
  })

  defschema(:nested_coerce, %{
    user: %{
      age: {:coerce, :string, :integer}
    }
  })

  defschema(:list_coerce, %{
    scores: {:list, {:coerce, :string, :integer}}
  })

  defschema(:custom_fun_coerce, %{
    amount: {:coerce, &parse_currency/1, :integer}
  })

  defschema(:custom_mfa_coerce, %{
    amount: {:coerce, {CustomCoercions, :parse_amount}, :integer},
    factored: {:coerce, {CustomCoercions, :parse_with_args, [10]}, :integer}
  })

  defschema(:constrained_coerce, %{
    age: {:coerce, :string, {:integer, {:gte, 18}}}
  })

  defschema(:required_coerce, %{
    page: {:required, {:coerce, :string, :integer}}
  })

  defschema(:default_coerce, %{
    page: {{:coerce, :string, :integer}, {:default, "5"}}
  })

  defschema(:encode_opt_field, %{
    name: {:string, {:encode, &String.upcase/1}}
  })

  defschema(:transform_field, %{
    number: {:integer, {:transform, &(&1 * 2)}}
  })

  defschema(:custom_encode_opt, %{
    page: {:coerce, :string, :integer, encode: &"page-#{&1}"}
  })

  defp parse_currency("$" <> rest), do: parse_currency(rest)

  defp parse_currency(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  defp parse_currency(_val), do: :error

  describe "built-in string coercions" do
    test "coerces string params into typed data" do
      params = %{"page" => "2", "per_page" => "50", "active" => "true"}
      assert {:ok, %{page: 2, per_page: 50, active: true}} = pagination(params)
    end

    test "float coercion accepts integers and floats" do
      assert {:ok, %{val: 1.0}} =
               Formata.NativeSchema.validate(%{val: {:coerce, :string, :float}}, %{
                 "val" => "1"
               })

      assert {:ok, %{val: 1.5}} =
               Formata.NativeSchema.validate(%{val: {:coerce, :string, :float}}, %{
                 "val" => "1.5"
               })
    end

    test "boolean coercion accepts only true and false" do
      schema = %{flag: {:coerce, :string, :boolean}}
      assert {:ok, %{flag: true}} = Formata.NativeSchema.validate(schema, %{"flag" => "true"})

      assert {:ok, %{flag: false}} =
               Formata.NativeSchema.validate(schema, %{"flag" => "false"})

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:flag],
                  message: "cannot coerce \"yes\" from :string to :boolean"
                }
              ]} = Formata.NativeSchema.validate(schema, %{"flag" => "yes"})
    end

    test "atom coercion uses existing atoms only" do
      schema = %{role: {:coerce, :string, :atom}}

      assert {:ok, %{role: :admin}} =
               Formata.NativeSchema.validate(schema, %{"role" => "admin"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:role], message: message}]} =
               Formata.NativeSchema.validate(schema, %{"role" => "nonexistent_atom_xyz_123"})

      assert message =~ "cannot coerce"
    end

    test "date and time coercions parse ISO 8601" do
      schema = %{
        date: {:coerce, :string, :date},
        time: {:coerce, :string, :time},
        naive: {:coerce, :string, :naive_datetime},
        dt: {:coerce, :string, :datetime}
      }

      data = %{
        "date" => "2024-03-15",
        "time" => "10:30:00",
        "naive" => "2024-03-15T10:30:00",
        "dt" => "2024-03-15T10:30:00Z"
      }

      assert {:ok,
              %{
                date: ~D[2024-03-15],
                time: ~T[10:30:00],
                naive: ~N[2024-03-15 10:30:00],
                dt: %DateTime{}
              }} = Formata.NativeSchema.validate(schema, data)
    end

    test "rejects partial integer parses" do
      schema = %{page: {:coerce, :string, :integer}}

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:page],
                  message: "cannot coerce \"12ab\" from :string to :integer"
                }
              ]} = Formata.NativeSchema.validate(schema, %{"page" => "12ab"})
    end

    test "rejects invalid ISO dates" do
      schema = %{date: {:coerce, :string, :date}}

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:date],
                  message: "cannot coerce \"2024-13-45\" from :string to :date"
                }
              ]} = Formata.NativeSchema.validate(schema, %{"date" => "2024-13-45"})
    end

    test "values already matching the target type pass through unchanged" do
      assert {:ok, %{page: 2, per_page: 50, active: true}} =
               pagination(%{page: 2, per_page: 50, active: true})

      schema = %{date: {:coerce, :string, :date}}

      assert {:ok, %{date: ~D[2024-03-15]}} =
               Formata.NativeSchema.validate(schema, %{date: ~D[2024-03-15]})
    end

    test "values matching neither target nor source return the target error" do
      schema = %{page: {:coerce, :string, :integer}}

      assert {:error, [%Formata.NativeSchema.Error{path: [:page], message: message}]} =
               Formata.NativeSchema.validate(schema, %{"page" => 1.5})

      assert message =~ "expected type of :integer"
    end
  end

  describe "nested and list coercion" do
    test "coerces inside nested schemas" do
      assert {:ok, %{user: %{age: 30}}} = nested_coerce(%{"user" => %{"age" => "30"}})
    end

    test "coerces each element of a list" do
      assert {:ok, %{scores: [1, 2, 3]}} = list_coerce(%{"scores" => ["1", "2", "3"]})
    end

    test "reports errors for elements that cannot be coerced" do
      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:scores, 1],
                  code: :coercion,
                  content: %{index: 1},
                  message: message
                }
              ]} =
               list_coerce(%{"scores" => ["1", "nope"]})

      assert message =~ "cannot coerce"
    end
  end

  describe "custom sources" do
    test "1-arity function source" do
      assert {:ok, %{amount: 2500}} = custom_fun_coerce(%{"amount" => "$2500"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:amount], message: message}]} =
               custom_fun_coerce(%{"amount" => "$abc"})

      assert message =~ "cannot coerce"
    end

    test "MFA source with and without args" do
      assert {:ok, %{amount: 4200, factored: 420}} =
               custom_mfa_coerce(%{"amount" => "42", "factored" => "42"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:amount], message: message}]} =
               custom_mfa_coerce(%{"amount" => "x", "factored" => "42"})

      assert message =~ "cannot coerce"
    end
  end

  describe "target constraints" do
    test "constraints on the target are enforced after coercion" do
      assert {:ok, %{age: 21}} = constrained_coerce(%{"age" => "21"})

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:age],
                  message: "should be greater then or equal to 18"
                }
              ]} = constrained_coerce(%{"age" => "17"})
    end
  end

  describe "string source shorthand" do
    test "{:coerce, target} defaults the source to :string" do
      schema = %{page: {:coerce, :integer}, active: {:coerce, :boolean}}

      assert {:ok, %{page: 2, active: true}} =
               Formata.NativeSchema.validate(schema, %{"page" => "2", "active" => "true"})
    end

    test "shorthand composes with target constraints" do
      schema = %{age: {:coerce, {:integer, gte: 18}}}
      assert {:ok, %{age: 21}} = Formata.NativeSchema.validate(schema, %{"age" => "21"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:age], message: message}]} =
               Formata.NativeSchema.validate(schema, %{"age" => "17"})

      assert message =~ "greater then or equal to 18"
    end

    test "{:coerce, target, opts} accepts coerce opts" do
      schema = %{tags: {:coerce, {:list, :string}, split: ","}}

      assert {:ok, %{tags: ["a", "b"]}} =
               Formata.NativeSchema.validate(schema, %{"tags" => "a,b"})
    end
  end

  describe "atom! targets" do
    test "creates new atoms from strings" do
      schema = %{role: {:coerce, :atom!}}

      assert {:ok, %{role: atom}} =
               Formata.NativeSchema.validate(schema, %{"role" => "brand_new_role_xyz"})

      assert atom == :brand_new_role_xyz
    end

    test "passes existing atoms through" do
      schema = %{role: {:coerce, :atom!}}
      assert {:ok, %{role: :admin}} = Formata.NativeSchema.validate(schema, %{role: :admin})
    end

    test "encodes atoms back to strings" do
      schema = %{role: {:coerce, :atom!}}
      assert {:ok, %{role: "admin"}} = Formata.NativeSchema.encode(schema, %{role: :admin})
    end
  end

  describe "enum and literal targets" do
    test "coerces strings into atom enum choices" do
      schema = %{role: {:coerce, {:enum, [:admin, :user]}}}

      assert {:ok, %{role: :admin}} =
               Formata.NativeSchema.validate(schema, %{"role" => "admin"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:role], message: message}]} =
               Formata.NativeSchema.validate(schema, %{"role" => "root"})

      assert message =~ "expected one of"
    end

    test "coerces into string and mixed enums" do
      assert {:ok, %{v: "a"}} =
               Formata.NativeSchema.validate(%{v: {:coerce, {:enum, ["a", "b"]}}}, %{
                 "v" => "a"
               })

      assert {:ok, %{v: 1}} =
               Formata.NativeSchema.validate(%{v: {:coerce, {:enum, [1, :two]}}}, %{
                 "v" => "1"
               })

      assert {:ok, %{v: :two}} =
               Formata.NativeSchema.validate(%{v: {:coerce, {:enum, [1, :two]}}}, %{
                 "v" => "two"
               })
    end

    test "enum opts are preserved" do
      schema = %{role: {:coerce, {:enum, [:admin, :user], error: "bad role"}}}

      assert {:error, [%Formata.NativeSchema.Error{path: [:role], message: "bad role"}]} =
               Formata.NativeSchema.validate(schema, %{"role" => "root"})
    end

    test "coerces strings into atom literals" do
      schema = %{status: {:coerce, {:literal, :active}}}

      assert {:ok, %{status: :active}} =
               Formata.NativeSchema.validate(schema, %{"status" => "active"})

      assert {:error, [%Formata.NativeSchema.Error{path: [:status], message: message}]} =
               Formata.NativeSchema.validate(schema, %{"status" => "archived"})

      assert message =~ "expected literal value"
    end

    test "coerces strings into boolean and integer literals" do
      assert {:ok, %{v: true}} =
               Formata.NativeSchema.validate(%{v: {:coerce, {:literal, true}}}, %{
                 "v" => "true"
               })

      assert {:ok, %{v: 42}} =
               Formata.NativeSchema.validate(%{v: {:coerce, {:literal, 42}}}, %{"v" => "42"})
    end

    test "values already matching the enum or literal pass through" do
      assert {:ok, %{role: :user}} =
               Formata.NativeSchema.validate(%{role: {:coerce, {:enum, [:admin, :user]}}}, %{
                 role: :user
               })

      assert {:ok, %{status: :active}} =
               Formata.NativeSchema.validate(%{status: {:coerce, {:literal, :active}}}, %{
                 status: :active
               })
    end

    test "encodes enum and literal targets back to strings" do
      assert {:ok, %{role: "admin"}} =
               Formata.NativeSchema.encode(%{role: {:coerce, {:enum, [:admin, :user]}}}, %{
                 role: :admin
               })

      assert {:ok, %{status: "active"}} =
               Formata.NativeSchema.encode(%{status: {:coerce, {:literal, :active}}}, %{
                 status: :active
               })
    end
  end

  describe "list targets with split" do
    test "splits and coerces each element" do
      schema = %{scores: {:coerce, {:list, :integer}, split: ","}}

      assert {:ok, %{scores: [1, 2, 3]}} =
               Formata.NativeSchema.validate(schema, %{"scores" => "1,2,3"})
    end

    test "accepts multiple separators and trims whitespace" do
      schema = %{scores: {:coerce, {:list, :integer}, split: [",", ";"]}}

      assert {:ok, %{scores: [1, 2, 3]}} =
               Formata.NativeSchema.validate(schema, %{"scores" => "1, 2; 3"})
    end

    test "empty string yields an empty list" do
      schema = %{scores: {:coerce, {:list, :integer}, split: ","}}
      assert {:ok, %{scores: []}} = Formata.NativeSchema.validate(schema, %{"scores" => ""})
    end

    test "enforces element constraints after coercion" do
      schema = %{scores: {:coerce, {:list, {:integer, gte: 2}}, split: ","}}

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:scores, 1],
                  code: :gte,
                  content: %{index: 1},
                  message: message
                }
              ]} =
               Formata.NativeSchema.validate(schema, %{"scores" => "2,1"})

      assert message =~ "greater then or equal to 2"
    end

    test "reports elements that cannot be coerced" do
      schema = %{scores: {:coerce, {:list, :integer}, split: ","}}

      assert {:error,
              [
                %Formata.NativeSchema.Error{
                  path: [:scores, 1],
                  code: :coercion,
                  content: %{index: 1},
                  message: message
                }
              ]} =
               Formata.NativeSchema.validate(schema, %{"scores" => "1,nope"})

      assert message =~ "cannot coerce"
    end

    test "coerces into lists of enums" do
      schema = %{roles: {:coerce, {:list, {:enum, [:admin, :user]}}, split: ","}}

      assert {:ok, %{roles: [:admin, :user]}} =
               Formata.NativeSchema.validate(schema, %{"roles" => "admin,user"})
    end

    test "lists already matching the target pass through" do
      schema = %{scores: {:coerce, {:list, :integer}, split: ","}}

      assert {:ok, %{scores: [1, 2]}} =
               Formata.NativeSchema.validate(schema, %{scores: [1, 2]})
    end

    test "encodes lists back to separated strings" do
      schema = %{scores: {:coerce, {:list, :integer}, split: ","}}

      assert {:ok, %{scores: "1,2,3"}} =
               Formata.NativeSchema.encode(schema, %{scores: [1, 2, 3]})

      roles = %{roles: {:coerce, {:list, {:enum, [:admin, :user]}}, split: [";", ","]}}

      assert {:ok, %{roles: "admin;user"}} =
               Formata.NativeSchema.encode(roles, %{roles: [:admin, :user]})
    end
  end

  describe "required and defaults" do
    test "required coerce fields reject missing values" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:page], message: message}]} =
               required_coerce(%{})

      assert message =~ "is required"
    end

    test "required coerce fields coerce present values" do
      assert {:ok, %{page: 7}} = required_coerce(%{"page" => "7"})
    end

    test "defaults flow through coercion" do
      assert {:ok, %{page: 5}} = default_coerce(%{})
      assert {:ok, %{page: 9}} = default_coerce(%{"page" => "9"})
    end
  end

  describe "encode/3" do
    test "encodes typed data back to the wire representation" do
      assert {:ok, %{"page" => "2", "since" => "2024-03-15"}} =
               Formata.NativeSchema.encode(wire_params_schema(), %{
                 "page" => 2,
                 "since" => ~D[2024-03-15]
               })
    end

    test "encode(decode(x)) round-trips string-sourced data" do
      wire = %{"page" => "2", "since" => "2024-03-15"}
      schema = wire_params_schema()

      assert {:ok, decoded} = Formata.NativeSchema.decode(schema, wire)
      assert decoded == %{"page" => 2, "since" => ~D[2024-03-15]}
      assert {:ok, encoded} = Formata.NativeSchema.encode(schema, decoded)
      assert encoded == wire
    end

    test "encode validates target types and does not coerce" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:page]}]} =
               Formata.NativeSchema.encode(pagination_schema(), %{"page" => "2"})
    end

    test "{:encode, fun} is applied on encode and ignored on validate" do
      assert {:ok, %{name: "hello"}} =
               Formata.NativeSchema.validate(encode_opt_schema(), %{name: "hello"})

      assert {:ok, %{name: "HELLO"}} =
               Formata.NativeSchema.encode(encode_opt_schema(), %{name: "hello"})
    end

    test "{:transform, fun} is applied on validate and skipped on encode" do
      assert {:ok, %{number: 8}} =
               Formata.NativeSchema.validate(transform_schema(), %{number: 4})

      assert {:ok, %{number: 4}} =
               Formata.NativeSchema.encode(transform_schema(), %{number: 4})
    end

    test "custom encode: opt overrides the built-in reverse" do
      assert {:ok, %{page: "page-3"}} =
               Formata.NativeSchema.encode(custom_encode_schema(), %{page: 3})
    end

    test "custom source without encode opt passes the value through on encode" do
      schema = %{amount: {:coerce, {CustomCoercions, :parse_amount}, :integer}}
      assert {:ok, %{amount: 42}} = Formata.NativeSchema.encode(schema, %{amount: 42})
    end
  end

  describe "decode/3" do
    test "is an alias of validate/3" do
      schema = pagination_schema()

      assert {:ok, %{page: 2, active: true}} =
               Formata.NativeSchema.decode(schema, %{"page" => "2", "active" => "true"})

      assert {:ok, %{page: 2}} = Formata.NativeSchema.decode(schema, %{page: 2})
    end
  end

  describe "schema-time validation" do
    test "accepts valid coerce definitions" do
      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, :string, :integer}})

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, {:integer, {:gte, 18}}}
               })

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, fn _ -> :error end, :any}})

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, {CustomCoercions, :parse_amount}, :integer}
               })

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, :integer, encode: &to_string/1}
               })

      assert {:ok, _} = Formata.NativeSchema.validate_schema(%{x: {:coerce, :integer}})
      assert {:ok, _} = Formata.NativeSchema.validate_schema(%{x: {:coerce, :atom!}})

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, {:enum, [:a, :b]}}})

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, {:literal, :active}}})

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, {:list, :integer}, split: ","}
               })

      assert {:ok, _} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, {:list, :integer}, split: [",", ";"]}
               })
    end

    test "rejects list targets without a split opt" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, {:list, :integer}}})

      assert message =~ "split: opt"
    end

    test "rejects invalid split opt values" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, {:list, :integer}, split: 44}
               })

      assert message =~ "expected split: opt"

      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, {:list, :integer}, split: []}
               })

      assert message =~ "expected split: opt"
    end

    test "rejects unsupported sources" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, :integer, :string}})

      assert message =~ "expected coerce source"
    end

    test "rejects unsupported built-in targets" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{x: {:coerce, :string, :map}})

      assert message =~ "expected coerce target for :string source"
    end

    test "rejects invalid nested target types" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x]}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, fn v -> {:ok, v} end, :not_a_type}
               })
    end

    test "rejects unknown or invalid coerce opts" do
      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, :integer, foo: 1}
               })

      assert message =~ "unknown coerce opts"

      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, :integer, encode: "up"}
               })

      assert message =~ "expected encode: opt"

      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, :integer, "encode"}
               })

      assert message =~ "keyword list"

      assert {:error, [%Formata.NativeSchema.Error{path: [:x], message: message}]} =
               Formata.NativeSchema.validate_schema(%{
                 x: {:coerce, :string, :integer, [:encode]}
               })

      assert message =~ "keyword list"
    end
  end

  describe "tooling integration" do
    test "json schema output uses the target type" do
      assert %{"properties" => %{"page" => %{"type" => "integer"}}} =
               Formata.NativeSchema.to_json_schema(%{page: {:coerce, :string, :integer}})
    end

    test "walker recurses into the coerce target" do
      schema = %{page: {:coerce, :string, {:required, :integer}}}

      assert %{page: {:coerce, :string, :integer}} =
               Formata.NativeSchema.walk(schema, fn
                 {:required, t} -> {:cont, t}
                 other -> {:cont, other}
               end)
    end
  end

  defp pagination_schema, do: get_schema(:pagination)
  defp wire_params_schema, do: get_schema(:wire_params)
  defp encode_opt_schema, do: get_schema(:encode_opt_field)
  defp transform_schema, do: get_schema(:transform_field)
  defp custom_encode_schema, do: get_schema(:custom_encode_opt)
end
