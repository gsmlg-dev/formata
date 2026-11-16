defmodule Formata.YAML.Writer.EncodeHelper do
  defmacro assert_identity(input, opts \\ []) do
    quote do: unquote(do_assert_identity(input, opts))
  end

  defmacro assert_output(input, exptected_output, opts \\ []) do
    quote do: unquote(do_assert_output(input, exptected_output, opts))
  end

  defmacro assert_identity_and_output(input, exptected_output, opts \\ []) do
    quote do
      unquote(do_assert_output(input, exptected_output, opts))
      unquote(do_assert_identity(input, opts))
    end
  end

  defp do_assert_identity(input, opts) do
    quote do
      assert unquote(input)
             |> Formata.YAML.Writer.document!(atoms: unquote(opts)[:atoms])
             |> Formata.YAML.Reader.read_from_string!(atoms: unquote(opts)[:atoms]) ==
               unquote(input)
    end
  end

  defp do_assert_output(input, exptected_output, opts) do
    quote do
      assert Formata.YAML.Writer.Encode.to_s!(unquote(input),
               atoms: unquote(opts)[:atoms],
               sort_maps: true
             ) ==
               unquote(exptected_output)
    end
  end
end
