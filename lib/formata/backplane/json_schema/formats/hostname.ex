defmodule Formata.Backplane.JsonSchema.Formats.Hostname do
  @moduledoc """
  Validates "hostname" format according to RFC 1123.
  """

  def valid?(data) when is_binary(data) do
    if ascii?(data) do
      validate_ascii_hostname(data)
    else
      false
    end
  end

  def valid?(_), do: true

  defp ascii_and_size_le_253?(<<>>), do: true

  defp ascii_and_size_le_253?(data) do
    ascii_and_size_le_253?(data, 0)
  end

  defp ascii_and_size_le_253?(_data, count) when count > 253, do: false

  defp ascii_and_size_le_253?(<<c, rest::binary>>, count) when c <= 127,
    do: ascii_and_size_le_253?(rest, count + 1)

  defp ascii_and_size_le_253?(<<c, _rest::binary>>, _count) when c > 127, do: false
  defp ascii_and_size_le_253?(<<>>, count) when count >= 0 and count <= 253, do: true
  defp ascii_and_size_le_253?(_, _), do: false

  def valid_idn?(data) when is_binary(data) do
    # Normalize IDNA separators to dots
    normalized = String.replace(data, ["\u3002", "\uFF0E", "\uFF61"], ".")

    if ascii_and_size_le_253?(normalized) do
      validate_ascii_hostname(normalized)
    else
      raise "The optional dependency :idna is required to validate idn-hostname with non-ASCII characters. Please add it to your mix.exs deps."
    end
  end

  def valid_idn?(_), do: true

  defp ascii?(<<>>), do: true
  defp ascii?(<<c, rest::binary>>) when c <= 127, do: ascii?(rest)
  defp ascii?(_), do: false

  defp validate_ascii_hostname(data) when byte_size(data) > 255, do: false

  defp validate_ascii_hostname(data) do
    # Check for empty labels (covers leading/trailing dots and consecutive dots)
    case check_and_split_hostname(data) do
      {:ok, labels} ->
        Enum.all?(labels, &valid_label?/1)

      _ ->
        false
    end
  end

  defp check_and_split_hostname(data) do
    labels = String.split(data, ".", trim: false)

    if Enum.any?(labels, &(&1 == "")) do
      :error
    else
      {:ok, labels}
    end
  end

  defp valid_label?(label) when byte_size(label) > 63, do: false

  defp valid_label?(label) do
    if String.starts_with?(String.downcase(label), "xn--") do
      validate_idn_label(label)
    else
      validate_std_label(label)
    end
  end

  defp validate_idn_label(_label) do
    raise "The optional dependency :idna is required to validate Punycode (A-label) hostnames. Please add it to your mix.exs deps."
  end

  # Check for hyphens in 3rd and 4th position (indices 2 and 3)
  # Since we are here, we know it does NOT start with xn--/XN-- etc.
  defp validate_std_label(<<_, _, ?-, ?-, _::binary>>), do: false

  # Single character label
  defp validate_std_label(<<c>>) when c in ?a..?z or c in ?A..?Z or c in ?0..?9, do: true

  # Multi-character label: first and last must be alphanumeric, middle can include hyphens
  defp validate_std_label(<<first, rest::binary>>)
       when first in ?a..?z or first in ?A..?Z or first in ?0..?9 do
    validate_std_label_middle(rest)
  end

  defp validate_std_label(_), do: false

  # Last character — must be alphanumeric
  defp validate_std_label_middle(<<c>>) when c in ?a..?z or c in ?A..?Z or c in ?0..?9, do: true
  defp validate_std_label_middle(<<c>>), do: c != ?- and false

  # Middle characters — alphanumeric or hyphen
  defp validate_std_label_middle(<<c, rest::binary>>)
       when c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?- do
    validate_std_label_middle(rest)
  end

  defp validate_std_label_middle(_), do: false
end
