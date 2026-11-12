# Release procedure

Releases are cut from `main` by a maintainer with Hex and GitHub credentials.

## Gate

All of these must pass on the commit to release:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors --force
mix test --include upstream_blocked   # includes the upstream regression tests
mix docs
mix hex.build
```

`--include upstream_blocked` is mandatory: those tests document dependency bugs
that would otherwise ship as silent data loss. If any fails, the release is
blocked until the dependency is fixed and updated (then remove the matching
`TODO(upstream)` markers and `@tag :upstream_blocked` attributes).

Also smoke-test the built package from an isolated consumer:

```sh
mix hex.build --unpack -o /tmp/formata-unpacked
# in a fresh project: {:formata, path: "/tmp/formata-unpacked"}; mix deps.get; run an example
```

## Steps

1. Update `@version` in `mix.exs` and the `CHANGELOG.md` entry.
2. Run the gate.
3. Commit, then tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`; push `main` and the tag.
   Never move or overwrite an existing tag or release.
4. Publish: `mix hex.publish` (package and docs).
5. Create the GitHub release from the tag with the changelog entry:
   `gh release create vX.Y.Z --title vX.Y.Z --notes-file <notes>`.
6. Verify https://hex.pm/packages/formata and https://hexdocs.pm/formata.
