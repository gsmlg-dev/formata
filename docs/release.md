# Release procedure

Releases are cut from `main` by a maintainer with Hex and GitHub credentials.

## Gate

The independent YAML checks require test-only `ruamel.yaml==0.18.16`.
Install it in a Python virtual environment and set
`FORMATA_YAML_REFERENCE_PYTHON` to that environment's interpreter, or install
the pinned version for `python3`. CI and Release install the same pin; it is
not a Formata runtime dependency. Python 3.11+ is also required for the
existing independent TOML `tomllib` checks.

All of these must pass on the commit to release:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors --force
mix test
mix docs
mix hex.build
```

`mix test` includes the ported upstream suites of the forked backends
(`test/formata/vendor/`), the TOML 1.0.0 `toml-test` suite, and the required
JSON-Schema-Test-Suite cases for Draft 7 and Draft 2020-12. Run it on the
oldest supported Elixir (1.18) as well; CI does.

Also smoke-test the built package from an isolated consumer:

```sh
mix hex.build --unpack -o /tmp/formata-unpacked
# in a fresh project: {:formata, path: "/tmp/formata-unpacked"}; mix deps.get; run an example
# (mix deps.get must fetch nothing: Formata has no runtime dependencies)
```

## Automated release

The `Release` workflow (`.github/workflows/release.yml`, manual dispatch with
`version` and `git_ref`) does steps 2–5 below: it sets `@version`, runs the
gate, commits `chore(release): vX.Y.Z` and pushes it with the annotated tag,
publishes to Hex with the `HEX_API_KEY` secret, and creates the GitHub release
from the `CHANGELOG.md` entry plus generated notes. Add the changelog entry
first; the workflow fails without it. Reruns are safe: an existing tag is only
accepted on the exact commit being released, and an already published Hex
version or existing GitHub release is skipped.

```sh
gh workflow run release.yml -f version=X.Y.Z -f git_ref=main
```

## Manual steps

1. Update `@version` in `mix.exs` and the `CHANGELOG.md` entry.
2. Run the gate.
3. Commit, then tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`; push `main` and the tag.
   Never move or overwrite an existing tag or release.
4. Publish: `mix hex.publish` (package and docs).
5. Create the GitHub release from the tag with the changelog entry:
   `gh release create vX.Y.Z --title vX.Y.Z --notes-file <notes>`.
6. Verify https://hex.pm/packages/formata and https://hexdocs.pm/formata.
