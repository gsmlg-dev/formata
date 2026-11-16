# Runs the eunit suite ported from yamerl 0.10.0 (test/**/*.erl, renamed to
# formata_yaml) under ExUnit.
#
# Each Erlang module under ./eunit is compiled when this file is compiled and
# every eunit test generator it exports (`*_test_/0`) or plain test function
# (`*_test/0`) becomes one ExUnit test. The eunit test representations used by
# the suite (`{setup, ...}`, `{generator, ...}`, `{Line, Fun}` from the `?_assert*`
# macros, lists and plain funs) are executed directly, so assertion failures
# surface as ExUnit failures. YAML fixtures live in test/fixtures/yaml/parser.
defmodule Formata.YAML.ParserTest do
  use ExUnit.Case, async: true

  @eunit_dir Path.expand("parser/eunit", __DIR__)

  # eunit.hrl (assertion macros and its autoexport parse transform) must be
  # resolvable by -include_lib when the suite modules are compiled.
  Mix.ensure_application!(:eunit)

  for path <- Enum.sort(Path.wildcard(Path.join(@eunit_dir, "**/*.erl"))) do
    @external_resource path

    module =
      case :compile.file(String.to_charlist(path), [:binary, :return_errors, :debug_info]) do
        {:ok, module, binary} ->
          {:module, ^module} = :code.load_binary(module, String.to_charlist(path), binary)
          module

        {:error, errors, _warnings} ->
          raise CompileError, description: "cannot compile #{path}: #{inspect(errors)}"
      end

    suite = Path.relative_to(path, @eunit_dir) |> Path.rootname()

    tests =
      for {fun, 0} <- module.module_info(:exports),
          name = Atom.to_string(fun),
          String.ends_with?(name, "_test_") or String.ends_with?(name, "_test"),
          do: fun

    if tests == [] do
      raise CompileError, description: "#{path} exports no eunit tests"
    end

    for fun <- Enum.sort(tests) do
      @tag yaml_parser_suite: suite
      test "#{suite} #{fun}" do
        module = unquote(module)
        fun = unquote(fun)

        if String.ends_with?(Atom.to_string(fun), "_test_") do
          run_eunit(apply(module, fun, []))
        else
          apply(module, fun, [])
        end
      end
    end
  end

  # Minimal interpreter for the eunit test representations used by the suite.
  defp run_eunit(tests) when is_list(tests), do: Enum.each(tests, &run_eunit/1)

  defp run_eunit({:setup, setup, instantiator}) do
    setup.() |> instantiate(instantiator) |> run_eunit()
  end

  defp run_eunit({:setup, setup, cleanup, instantiator}) do
    state = setup.()

    try do
      state |> instantiate(instantiator) |> run_eunit()
    after
      cleanup.(state)
    end
  end

  defp run_eunit({:generator, generator}) when is_function(generator, 0),
    do: run_eunit(generator.())

  defp run_eunit({line, fun}) when is_integer(line) and is_function(fun, 0),
    do: run_eunit_fun(fun, line)

  defp run_eunit(fun) when is_function(fun, 0), do: run_eunit_fun(fun, nil)

  defp run_eunit(other), do: flunk("unsupported eunit test representation: #{inspect(other)}")

  defp instantiate(state, instantiator) when is_function(instantiator, 1),
    do: instantiator.(state)

  defp instantiate(_state, tests), do: tests

  defp run_eunit_fun(fun, line) do
    fun.()
  rescue
    error in ErlangError ->
      case error.original do
        {kind, info} when is_list(info) ->
          if Keyword.keyword?(info) and Keyword.has_key?(info, :expression) do
            reraise ExUnit.AssertionError,
                    [
                      message:
                        "eunit #{kind} (#{info[:module]}:#{info[:line] || line})\n" <>
                          "expression: #{info[:expression]}\n" <>
                          Enum.map_join(
                            Keyword.drop(info, [:module, :line, :expression]),
                            "\n",
                            fn {k, v} -> "#{k}: #{inspect(v, pretty: true, limit: :infinity)}" end
                          )
                    ],
                    __STACKTRACE__
          else
            reraise error, __STACKTRACE__
          end

        _ ->
          reraise error, __STACKTRACE__
      end
  end
end
