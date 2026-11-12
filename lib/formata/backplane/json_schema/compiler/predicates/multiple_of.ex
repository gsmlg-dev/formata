defmodule Formata.Backplane.JsonSchema.Compiler.Predicates.MultipleOf do
  @moduledoc """
  Validates numbers against the JSON Schema `multipleOf` rule.

  Numbers are compared as exact decimals: an integer as itself, a float as the
  shortest decimal that reads back as the same float (the JSON text it came
  from). The check uses integer arithmetic only, so it neither overflows nor
  depends on floating-point tolerances.

  Formata fork change: upstream used `Decimal` when available and otherwise a
  floating-point quotient that raised `ArithmeticError` on overflow (for
  example `1.0e308` against `0.123456789`) and accepted near misses within
  `1.0e-9`. The algorithm below is upstream's `Decimal` branch on plain
  `{coefficient, exponent}` pairs.
  """

  @doc """
  Checks if `instance` is a multiple of `divisor`.

  Returns `false` for non-numbers and for a divisor that is not positive.

  ## Examples

      iex> Formata.Backplane.JsonSchema.Compiler.Predicates.MultipleOf.valid?(0.0075, 0.0001)
      true

      iex> Formata.Backplane.JsonSchema.Compiler.Predicates.MultipleOf.valid?(1.0e-10, 1)
      false

      iex> Formata.Backplane.JsonSchema.Compiler.Predicates.MultipleOf.valid?(1.0e308, 0.123456789)
      false
  """
  @spec valid?(term(), term()) :: boolean()
  def valid?(instance, divisor) when is_number(instance) and is_number(divisor) and divisor > 0 do
    exact_multiple?(to_decimal(instance), to_decimal(divisor))
  end

  def valid?(_instance, _divisor), do: false

  # A decimal is `coefficient * 10 ^ exponent` with a non-negative coefficient.
  defp exact_multiple?({0, _}, _divisor), do: true

  defp exact_multiple?({coefficient_i, exponent_i}, {coefficient_d, exponent_d}) do
    case exponent_i - exponent_d do
      shift when shift >= 0 ->
        remaining_divisor = div(coefficient_d, Integer.gcd(coefficient_i, coefficient_d))
        divides_power_of_ten?(remaining_divisor, shift)

      shift ->
        rem(coefficient_i, coefficient_d) == 0 and
          divisible_by_power_of_ten?(div(coefficient_i, coefficient_d), -shift)
    end
  end

  defp divides_power_of_ten?(1, _shift), do: true

  defp divides_power_of_ten?(divisor, shift) do
    {remaining, twos} = factor_out(divisor, 2, 0)
    {remaining, fives} = factor_out(remaining, 5, 0)

    remaining == 1 and twos <= shift and fives <= shift
  end

  defp divisible_by_power_of_ten?(0, _shift), do: true
  defp divisible_by_power_of_ten?(_coefficient, 0), do: true

  defp divisible_by_power_of_ten?(coefficient, shift) when rem(coefficient, 10) == 0 do
    divisible_by_power_of_ten?(div(coefficient, 10), shift - 1)
  end

  defp divisible_by_power_of_ten?(_coefficient, _shift), do: false

  defp factor_out(value, factor, count) when rem(value, factor) == 0 do
    factor_out(div(value, factor), factor, count + 1)
  end

  defp factor_out(value, _factor, count), do: {value, count}

  defp to_decimal(integer) when is_integer(integer), do: {abs(integer), 0}

  # `:short` yields the shortest decimal that round-trips, such as "0.0075",
  # "1.0e308" or "1.0e-10".
  defp to_decimal(float) when is_float(float) do
    {mantissa, exponent} =
      case :binary.split(:erlang.float_to_binary(abs(float), [:short]), "e") do
        [mantissa, exponent] -> {mantissa, String.to_integer(exponent)}
        [mantissa] -> {mantissa, 0}
      end

    {int, frac} =
      case :binary.split(mantissa, ".") do
        [int, frac] -> {int, frac}
        [int] -> {int, ""}
      end

    {String.to_integer(int <> frac), exponent - byte_size(frac)}
  end
end
