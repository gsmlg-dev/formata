defmodule Formata.JSONSchema.Formats.Hostname do
  @moduledoc """
  Validates "hostname" format according to RFC 1123.

  Deciding whether an A-label (`xn--...`) or a U-label (a non-ASCII label of an
  `idn-hostname`) is valid requires the IDNA2008 Unicode tables (RFC 5891,
  5892, 5893), which this library does not ship. Such inputs are reported as
  indeterminate instead of being accepted or rejected (see
  `Formata.JSONSchema.Formats`), unless another label already makes
  the name invalid. Formata fork change: upstream raised a `RuntimeError`
  asking for the optional `:idna` dependency.
  """

  @indeterminate_a_label "A-labels (xn--) cannot be validated without IDNA2008 tables"
  @indeterminate_u_label "non-ASCII labels cannot be validated without IDNA2008 tables"

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

    cond do
      ascii_and_size_le_253?(normalized) ->
        validate_ascii_hostname(normalized)

      ascii?(normalized) ->
        false

      true ->
        validate_unicode_hostname(normalized)
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
      {:ok, labels} -> labels |> Enum.map(&label_validity/1) |> combine()
      _ -> false
    end
  end

  # Non-ASCII labels are U-labels. An invalid ASCII label still decides the
  # result; otherwise the name is indeterminate.
  defp validate_unicode_hostname(data) do
    case check_and_split_hostname(data) do
      {:ok, labels} ->
        labels
        |> Enum.map(fn label ->
          if ascii?(label),
            do: label_validity(label),
            else: {:indeterminate, @indeterminate_u_label}
        end)
        |> combine()

      _ ->
        false
    end
  end

  defp combine(results) do
    cond do
      false in results -> false
      reason = Enum.find_value(results, &indeterminate_reason/1) -> indeterminate(reason)
      true -> true
    end
  end

  defp indeterminate_reason({:indeterminate, reason}), do: reason
  defp indeterminate_reason(_), do: nil

  defp indeterminate(reason),
    do: throw({Formata.JSONSchema.Formats, :indeterminate, reason})

  defp check_and_split_hostname(data) do
    labels = String.split(data, ".", trim: false)

    if Enum.any?(labels, &(&1 == "")) do
      :error
    else
      {:ok, labels}
    end
  end

  defp label_validity(label) when byte_size(label) > 63, do: false

  defp label_validity(label) do
    if String.starts_with?(String.downcase(label), "xn--") do
      a_label_validity(label)
    else
      validate_std_label(label)
    end
  end

  # An A-label is an LDH label, so anything else is invalid. Whether its
  # Punycode encodes a valid U-label cannot be decided here.
  defp a_label_validity(label) do
    if ldh_label?(label), do: {:indeterminate, @indeterminate_a_label}, else: false
  end

  defp ldh_label?(label) do
    not String.ends_with?(label, "-") and
      label
      |> :binary.bin_to_list()
      |> Enum.all?(&(&1 in ?a..?z or &1 in ?A..?Z or &1 in ?0..?9 or &1 == ?-))
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
