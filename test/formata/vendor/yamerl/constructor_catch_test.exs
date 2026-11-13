defmodule Formata.Vendor.YamerlConstructorCatchTest do
  use ExUnit.Case, async: false

  @first :formata_yamerl_test_probe_first
  @second :formata_yamerl_test_probe_second
  @non_constructor :formata_yamerl_test_probe_non_constructor
  @missing :formata_yamerl_test_probe_missing
  @probe_modules [@first, @second, @non_constructor, @missing]

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "formata-yamerl-probes-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)

    on_exit(fn ->
      for module <- @probe_modules do
        :code.purge(module)
        :code.delete(module)
      end

      :code.del_path(String.to_charlist(directory))
      File.rm_rf!(directory)
    end)

    for {module, result} <- [
          {@first, :first},
          {@second, :second},
          {@non_constructor, :non_constructor},
          {@missing, :missing}
        ] do
      beam = compile_probe(directory, module, result)
      File.write!(Path.join(directory, "#{module}.beam"), beam)
    end

    path = String.to_charlist(directory)
    true = :code.add_patha(path)

    {:ok, directory: directory}
  end

  setup do
    for module <- @probe_modules do
      :code.purge(module)
      :code.delete(module)
    end

    :ok
  end

  test "binary construction preserves valid, empty and whitespace input in both modes" do
    for {input, expected} <- [
          {"!!binary Zm9v", "foo"},
          {"!!binary Zg==", "f"},
          {"!!binary \"\"", ""},
          {"!!binary ' Zm9v '", "foo"},
          {"!!binary \"Zm\\t9v\\r\\n\"", "foo"},
          {"!!binary |\n  Zm\n  9v\n", "foo"}
        ] do
      assert [^expected] = :formata_yamerl_constr.string(input, detailed_constr: false)

      assert [
               {:formata_yamerl_doc,
                {:formata_yamerl_binary, :formata_yamerl_node_binary,
                 ~c"tag:yaml.org,2002:binary", [line: 1, column: 10], ^expected}}
             ] = :formata_yamerl_constr.string(input, detailed_constr: true)

      assert {:ok, ^expected} = Formata.decode(input, :yaml)
    end
  end

  test "invalid characters and padding preserve binary errors, tokens and locations" do
    for encoded <- ["!", "Zg", "Zg=", "Z==="], detailed <- [false, true] do
      input = "outer:\n  value: !!binary '#{encoded}'"

      assert {:formata_yamerl_exception,
              [
                {:formata_yamerl_parsing_error, :error, ~c"Invalid binary/Not base64", 2, 19,
                 :not_a_binary, token, []}
              ]} =
               catch_throw(:formata_yamerl_constr.string(input, detailed_constr: detailed))

      assert token ==
               {:formata_yamerl_scalar, 2, 19,
                {:formata_yamerl_tag, 2, 10, ~c"tag:yaml.org,2002:binary"}, :flow, :single_quoted,
                String.to_charlist(encoded)}

      assert {:error,
              [
                %Formata.Error{
                  kind: :parse,
                  code: :syntax,
                  location: %{line: 2, column: 19},
                  details: %{type: :not_a_binary}
                }
              ]} = Formata.decode(input, :yaml)
    end
  end

  test "loaded constructor modules retain their autodetection behavior" do
    assert {:module, @first} = :code.load_file(@first)
    assert :erlang.function_exported(@first, :try_construct_token, 3)
    assert [:first] = :formata_yamerl_constr.string("value", node_mods: [@first])
  end

  test "available but unloaded constructors are loaded before export checks in order" do
    parser = :formata_yamerl_constr.new(:probe, node_mods: [@first, @second])
    unload(@first)
    unload(@second)
    assert :code.is_loaded(@first) == false
    assert :code.is_loaded(@second) == false
    refute :erlang.function_exported(@first, :try_construct_token, 3)
    refute :erlang.function_exported(@second, :try_construct_token, 3)

    assert [:first] = :formata_yamerl_constr.last_chunk(parser, "value")
    assert {:file, _} = :code.is_loaded(@first)
    assert {:file, _} = :code.is_loaded(@second)
    assert [:second] = :formata_yamerl_constr.string("value", node_mods: [@second, @first])
  end

  test "missing and non-constructor modules are ignored before the next constructor", %{
    directory: directory
  } do
    # Validate the callback modules first, then change their availability
    # before the first document invokes the autodetection filter. This avoids
    # the option validator's earlier module_info call masking the filter's
    # own loading behavior.
    parser =
      :formata_yamerl_constr.new(:probe, node_mods: [@missing, @non_constructor, @first])

    missing_path = Path.join(directory, "#{@missing}.beam")
    non_constructor_path = Path.join(directory, "#{@non_constructor}.beam")
    missing_beam = File.read!(missing_path)
    non_constructor_beam = File.read!(non_constructor_path)

    try do
      File.rm!(missing_path)
      File.write!(non_constructor_path, compile_probe(directory, @non_constructor, nil))
      unload(@missing)
      unload(@non_constructor)
      assert :code.which(@missing) == :non_existing
      assert :code.is_loaded(@non_constructor) == false

      assert [:first] = :formata_yamerl_constr.last_chunk(parser, "value")
      assert {:file, _} = :code.is_loaded(@non_constructor)
      refute :erlang.function_exported(@non_constructor, :try_construct_token, 3)
      assert :code.is_loaded(@missing) == false
    after
      unload(@missing)
      unload(@non_constructor)
      File.write!(missing_path, missing_beam)
      File.write!(non_constructor_path, non_constructor_beam)
    end
  end

  defp compile_probe(directory, module, result) do
    source = Path.join(directory, "#{module}.erl")

    {exports, body} =
      if result do
        {"-export([try_construct_token/3, construct_token/3, node_pres/1]).\n",
         "try_construct_token(A, B, C) -> construct_token(A, B, C).\n" <>
           "construct_token(_, _, _) -> {finished, #{result}}.\nnode_pres(_) -> [].\n"}
      else
        {"", ""}
      end

    File.write!(
      source,
      "-module(#{module}).\n-export([tags/0]).\n" <> exports <> "tags() -> [].\n" <> body
    )

    {:ok, ^module, beam} =
      :compile.file(String.to_charlist(source), [:binary, :return_errors, :warnings_as_errors])

    beam
  end

  defp unload(module) do
    :code.purge(module)
    :code.delete(module)
  end
end
