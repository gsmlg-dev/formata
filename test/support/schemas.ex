defmodule Formata.Test.Schemas do
  @moduledoc false
  import Formata.NativeSchema

  defschema(:address, %{city: {:required, :string}, zip: {:string, regex: ~r/^\d{5}$/}})

  defschema(:person, %{
    name: {:required, :string},
    address: {:ref, :address},
    friends: {:list, {:ref, :person}}
  })

  defschema(:with_default, %{port: {:integer, {:default, 80}}})

  def even(value) when is_integer(value) and rem(value, 2) == 0, do: :ok
  def even(value), do: {:error, "%{value} is not even", value: value}
end
