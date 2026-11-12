# Ported from backplane_json_schema 1.10.76
# (test/backplane/json_schema/conformance_test.exs). Upstream runs the required
# (non-optional) Draft 2020-12 files of the official JSON-Schema-Test-Suite at a
# pinned commit; the port runs the same files and, in addition, the required
# Draft 7 files at the same commit. Fixtures: test/fixtures/JSON-Schema-Test-Suite
# (see its PROVENANCE.md).
#
# Changes from upstream:
#   * one ExUnit test per suite file (upstream: one test for all files, stopping
#     at the first failing case); every case of a file is checked and all
#     failures are reported together;
#   * the official repository layout (tests/<dialect>, remotes/) instead of
#     upstream's copy in backplane_agent_runtime/test/fixtures;
#   * remote references resolve `http://localhost:1234/<path>` to
#     `remotes/<path>` for both dialects (upstream mapped only the
#     `draft2020-12/` prefix, plus every `urn:` URI to one fixture file; no
#     case needs that mapping, so it is not ported);
#   * Draft 7 files are compiled with `draft: "draft7"` because their schemas
#     do not declare `$schema`.
#
# Skips: upstream skips nothing. @skips lists every case that is not expected
# to pass, with the reason. A listed case that passes fails the run, so the
# list cannot go stale.
defmodule Formata.Vendor.BackplaneJsonSchema.ConformanceTest do
  use ExUnit.Case, async: true

  @suite_root Path.expand("../../../fixtures/JSON-Schema-Test-Suite", __DIR__)
  @suite_commit "5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8"
  @remote_root Path.join(@suite_root, "remotes")
  @remote_base "http://localhost:1234/"

  @dialects [{"draft2020-12", []}, {"draft7", [draft: "draft7"]}]

  # {dialect, file, group description, test description} => reason
  @skips %{}

  test "the vendored suite is the pinned commit" do
    assert File.read!(Path.join(@suite_root, "COMMIT")) |> String.trim() == @suite_commit
  end

  for {dialect, opts} <- @dialects do
    files =
      @suite_root
      |> Path.join("tests/#{dialect}/*.json")
      |> Path.wildcard()
      |> Enum.sort()

    if files == [], do: raise("no JSON-Schema-Test-Suite files for #{dialect}")

    for file <- files do
      @external_resource file
      name = Path.basename(file)

      @tag dialect: dialect
      test "#{dialect}/#{name}" do
        run_file(unquote(dialect), unquote(file), unquote(opts))
      end
    end
  end

  test "keeps format and content assertions annotation-only by default" do
    {:ok, schema} =
      Formata.Backplane.JsonSchema.compile(%{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "type" => "string",
        "format" => "email",
        "contentEncoding" => "base64",
        "contentMediaType" => "application/json"
      })

    assert :ok = Formata.Backplane.JsonSchema.validate(schema, "not-an-email")
  end

  test "supports opt-in format assertion without changing the default policy" do
    {:ok, schema} =
      Formata.Backplane.JsonSchema.compile(
        %{
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          "type" => "string",
          "format" => "email"
        },
        format_assertion: true
      )

    assert {:error, errors} = Formata.Backplane.JsonSchema.validate(schema, "not-an-email")
    assert Enum.any?(errors, &(&1.rule == :format))
  end

  defp run_file(dialect, file, opts) do
    name = Path.basename(file)

    results =
      for group <- file |> File.read!() |> JSON.decode!(),
          result <- run_group(group, opts),
          do: result

    failures =
      for {group, description, outcome} <- results,
          outcome != :pass,
          not Map.has_key?(@skips, {dialect, name, group, description}),
          do: "#{dialect}/#{name} / #{group} / #{description}: #{outcome}"

    stale_skips =
      for {group, description, :pass} <- results,
          Map.has_key?(@skips, {dialect, name, group, description}),
          do: "#{dialect}/#{name} / #{group} / #{description}"

    assert failures == [], "failing cases:\n" <> Enum.join(failures, "\n")
    assert stale_skips == [], "skipped cases that now pass:\n" <> Enum.join(stale_skips, "\n")
  end

  defp run_group(%{"schema" => schema, "tests" => tests, "description" => group}, opts) do
    case Formata.Backplane.JsonSchema.compile(schema, Keyword.put(opts, :loader, &load_remote/1)) do
      {:ok, compiled} ->
        Enum.map(tests, fn %{"data" => data, "valid" => expected, "description" => description} ->
          actual = Formata.Backplane.JsonSchema.validate(compiled, data)

          outcome =
            cond do
              actual == :ok == expected -> :pass
              expected -> "expected valid, got #{inspect(actual, limit: 3)}"
              true -> "expected invalid, got :ok"
            end

          {group, description, outcome}
        end)

      {:error, error} ->
        for %{"description" => description} <- tests,
            do: {group, description, "schema did not compile: #{inspect(error, limit: 5)}"}
    end
  end

  defp load_remote(@remote_base <> path) do
    file = Path.join(@remote_root, path)

    if File.regular?(file),
      do: {:ok, file |> File.read!() |> JSON.decode!()},
      else: {:error, {:remote_fixture_not_found, path}}
  end

  defp load_remote(uri), do: {:error, {:remote_fixture_not_found, uri}}
end
