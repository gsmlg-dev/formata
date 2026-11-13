defmodule Formata.Codec.YAMLReferenceTest do
  use ExUnit.Case, async: true

  @python System.get_env("FORMATA_YAML_REFERENCE_PYTHON") || System.find_executable("python3")
  @script Path.expand("../../support/yaml_reference.py", __DIR__)
  @reference_available (case @python do
                          nil ->
                            false

                          python ->
                            match?(
                              {_, 0},
                              System.cmd(
                                python,
                                [
                                  "-I",
                                  "-c",
                                  "import ruamel.yaml; assert ruamel.yaml.__version__ == '0.18.16'"
                                ],
                                stderr_to_stdout: true
                              )
                            )
                        end)

  if not @reference_available and System.get_env("CI") do
    raise "CI requires test-only ruamel.yaml==0.18.16 for independent YAML checks"
  end

  if not @reference_available,
    do: @tag(skip: "install test-only ruamel.yaml==0.18.16 or set FORMATA_YAML_REFERENCE_PYTHON")

  test "emitted strings and scalar key types agree with independent YAML 1.2 nodes" do
    strings =
      [
        " a\nb",
        " a\n b",
        "a\r\nb",
        "a\n\u0000",
        "",
        "nil",
        "null",
        ".5",
        "true",
        "1",
        "<<",
        "a\"b\\c",
        " leading",
        "trailing ",
        "\n",
        "\n\n",
        "a\n",
        "a\n\n",
        "a\n\nb",
        "\n a\n",
        "a\t#b",
        "雪😀",
        "\uFEFF",
        "\uFEFFx"
      ] ++ for(codepoint <- 0..31, do: "a\n" <> <<codepoint::utf8>>)

    data =
      [
        nil,
        true,
        false,
        1,
        -2,
        0.5,
        :infinity,
        :negative_infinity,
        :nan,
        [],
        %{},
        %{1 => "int", "1" => "string", true => "bool", "true" => "string", "<<" => nil}
      ] ++
        Enum.flat_map(strings, fn value -> [value, [value], %{"v" => value}, %{value => 1}] end)

    documents =
      Enum.map(data, fn value ->
        assert {:ok, yaml} = Formata.encode(value, :yaml)
        yaml
      end)

    path =
      Path.join(
        System.tmp_dir!(),
        "formata-yaml-reference-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(path) end)
    File.write!(path, Formata.Jason.encode!(documents))
    {output, status} = System.cmd(@python, ["-I", @script, path], stderr_to_stdout: true)
    assert status == 0, output
    assert Formata.Jason.decode!(output) == Enum.map(data, &typed/1)
  end

  defp typed(nil), do: ["null"]
  defp typed(value) when is_boolean(value), do: ["bool", value]
  defp typed(value) when is_integer(value), do: ["int", value]
  defp typed(value) when is_float(value), do: ["float", value]
  defp typed(:infinity), do: ["float", "inf"]
  defp typed(:negative_infinity), do: ["float", "-inf"]
  defp typed(:nan), do: ["float", "nan"]
  defp typed(value) when is_binary(value), do: ["str", value]
  defp typed(value) when is_list(value), do: ["list", Enum.map(value, &typed/1)]

  defp typed(value) when is_map(value) do
    pairs =
      value
      |> Enum.map(fn {k, v} -> [typed(k), typed(v)] end)
      |> Enum.sort_by(fn [k, _] -> Formata.Jason.encode!(k) end)

    ["map", pairs]
  end
end
