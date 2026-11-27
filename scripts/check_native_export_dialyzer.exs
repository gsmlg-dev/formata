# Run with MIX_ENV=prod mix run --no-start scripts/check_native_export_dialyzer.exs.
# Formata is a dependency in the PLT; only the unannotated consumer fixtures
# are analyzed for warnings, matching the original downstream reproduction.

# Mix prunes applications that are not runtime dependencies. Restore the OTP
# tools for this process without adding development tools to Formata's package.
Enum.each(
  [:dialyzer, :compiler, :syntax_tools, :tools, :crypto, :xmerl],
  &Mix.ensure_application!/1
)

root = Path.expand("..", __DIR__)
build = Path.join(Mix.Project.build_path(), "native_export_dialyzer")
probe_path = Path.join(build, "consumer")
File.mkdir_p!(build)

applications = [:erts, :kernel, :stdlib, :compiler, :elixir, :logger, :crypto, :xmerl]

ebin_paths =
  Enum.map(applications, fn app ->
    case :code.lib_dir(app, :ebin) do
      {:error, reason} -> Mix.raise("Cannot locate #{app}: #{inspect(reason)}")
      path -> List.to_string(path)
    end
  end) ++ [Mix.Project.compile_path()]

dependency_beams =
  ebin_paths
  |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*.beam")))
  |> Enum.sort()

# A stale dependency PLT can hide or reproduce a fixed bug. Include every
# dependency's path and contents, plus the analyzer version, in the cache key.
dialyzer_version = Application.spec(:dialyzer, :vsn)

fingerprint =
  dependency_beams
  |> Enum.reduce(:crypto.hash_init(:sha256), fn path, hash ->
    :crypto.hash_update(hash, [path, 0, File.read!(path)])
  end)
  |> :crypto.hash_update(:erlang.term_to_binary({System.version(), dialyzer_version}))
  |> :crypto.hash_final()
  |> Base.encode16(case: :lower)

plt = Path.join(build, "dependencies-#{fingerprint}.plt")

IO.puts(
  "Checking native schema consumers with Elixir #{System.version()} / OTP #{System.otp_release()}"
)

unless File.regular?(plt) do
  IO.puts("Building the Formata dependency PLT")

  :dialyzer.run(
    analysis_type: :plt_build,
    files: Enum.map(dependency_beams, &String.to_charlist/1),
    output_plt: String.to_charlist(plt)
  )
end

# Always compile the fixtures again, so removed/renamed modules cannot remain
# in the analysis and no consumer result is cached.
File.rm_rf!(probe_path)
File.mkdir_p!(probe_path)

fixtures =
  Enum.map(["native_export_probe.ex", "native_schema_probe.ex"], fn name ->
    Path.join([root, "scripts/fixtures/dialyzer", name])
  end)

case Kernel.ParallelCompiler.compile_to_path(fixtures, probe_path, return_diagnostics: true) do
  {:ok, _, %{compile_warnings: [], runtime_warnings: []}} -> :ok
  result -> Mix.raise("Consumer fixture compilation failed: #{inspect(result)}")
end

warnings =
  :dialyzer.run(
    analysis_type: :succ_typings,
    init_plt: String.to_charlist(plt),
    files_rec: [String.to_charlist(probe_path)],
    warnings: [:unknown, :unmatched_returns, :error_handling, :underspecs]
  )

case warnings do
  [] ->
    IO.puts("Native schema consumer Dialyzer check passed (zero warnings)")

  warnings ->
    Enum.each(warnings, &IO.puts(:dialyzer.format_warning(&1)))
    Mix.raise("Native schema consumer Dialyzer check failed with #{length(warnings)} warning(s)")
end
