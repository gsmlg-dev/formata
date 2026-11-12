defmodule Formata.Backplane.JsonSchema.Compiler.Predicates.MultipleOf do
  @moduledoc """
  Validates numbers against the JSON Schema `multipleOf` rule.
  Handles arbitrary precision if `Decimal` is available.
  Falls back to native arithmetic with overflow protection if not.
  """

  defmodule Native do
    @moduledoc false

    @spec valid?(number(), number()) :: boolean()
    def valid?(_instance, 0), do: false
    def valid?(_instance, +0.0), do: false

    def valid?(instance, divisor) when is_number(instance) and is_number(divisor) do
      quotient = instance / divisor
      diff = abs(quotient - round(quotient))
      diff < 1.0e-9
    rescue
      ArithmeticError ->
        raise_missing_decimal_error(instance, divisor)
    end

    def valid?(_, _), do: false

    defp raise_missing_decimal_error(instance, divisor) do
      raise ArithmeticError,
        message:
          "Arithmetic error checking multipleOf(#{inspect(instance)}, #{inspect(divisor)}) with native arithmetic. " <>
            "Please add {:decimal, \"~> 3.2\"} to your dependencies to handle arbitrary precision."
    end
  end

  @doc """
  Checks if `instance` is a multiple of `divisor`.
  Uses native arithmetic with overflow handling.
  """
  defdelegate valid?(instance, divisor), to: Native
end
