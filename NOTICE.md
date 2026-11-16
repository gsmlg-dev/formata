# Third-party notices

Formata has no runtime dependencies. Its codec and schema backends are
maintained forks of the packages below, copied from the published Hex
releases, renamed into the `Formata` namespace, and modified as described.
The original license texts are in [`LICENSES/`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/) and are shipped in
the Hex package.

| Upstream package | Version | Source | License | Formata location |
| --- | --- | --- | --- | --- |
| `jason` | 1.4.5 | https://github.com/michalmuskala/jason (tag `v1.4.5`, `4ede428`) | Apache-2.0 ([`LICENSES/jason.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/jason.txt), [`LICENSES/Apache-2.0.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/Apache-2.0.txt)) | `Formata.JSON.Backend*` — `lib/formata/json/backend*` |
| `gsmlg_toml` | 1.0.0 | https://github.com/gsmlg-dev/gsmlg_umbrella (`apps/gsmlg_toml`; no release tag — `lib/` identical to the Hex release at `ce41864` except the unforked `provider.ex`) | Apache-2.0 (package metadata; the repository `LICENSE` at `ce41864` is Apache-2.0 followed by a retained MIT notice) — the Hex 1.0.0 release shipped only the MIT notice ([`LICENSES/gsmlg_toml.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/gsmlg_toml.txt)); both texts are included ([`LICENSES/Apache-2.0.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/Apache-2.0.txt)) | `Formata.TOML*` — `lib/formata/toml*` |
| `yaml_elixir` | 2.12.2 | https://github.com/KamilLelonek/yaml-elixir (tag `v2.12.2`, `4c5ee04`) | MIT ([`LICENSES/yaml_elixir.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/yaml_elixir.txt)) | `Formata.YAML.Reader*` — `lib/formata/yaml/reader*` |
| `yamerl` | 0.10.0 | https://github.com/yakaz/yamerl (tag `v0.10.0`, `39981b9`) | BSD-2-Clause ([`LICENSES/yamerl.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/yamerl.txt)) | `formata_yaml*` — `src/`, `include/` |
| `ymlr` | 5.1.6 | https://github.com/ufirstgroup/ymlr (tag `v5.1.6`, `85bdb49`) | MIT ([`LICENSES/ymlr.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/ymlr.txt)) | `Formata.YAML.Writer*` — `lib/formata/yaml/writer*` |
| `backplane_schema` | 1.10.76 | https://github.com/gsmlg-opt/backplane (tag `v1.10.76`, `8330b68`, `apps/backplane_schema`) | MIT ([`LICENSES/backplane_schema.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/backplane_schema.txt)) | `Formata.NativeSchema*` — `lib/formata/native_schema*` |
| `backplane_json_schema` | 1.10.76 | https://github.com/gsmlg-opt/backplane (tag `v1.10.76`, `8330b68`, `apps/backplane_json_schema`) | Apache-2.0, declared in package metadata; no license file or copyright notice is shipped upstream ([`LICENSES/Apache-2.0.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/Apache-2.0.txt)) | `Formata.JSONSchema*` — `lib/formata/json_schema*` |
| `ex_json_pointer` | 0.9.0 | https://github.com/xinz/ex_json_pointer | MIT ([`LICENSES/ex_json_pointer.txt`](https://github.com/gsmlg-dev/formata/blob/main/LICENSES/ex_json_pointer.txt)) | `Formata.JSONPointer*` — `lib/formata/json_pointer*` |

## Modifications common to all forks

- Modules use Formata's own names (`Jason` → `Formata.JSON.Backend`,
  `Backplane.Schema` → `Formata.NativeSchema`, …); yamerl's Erlang modules,
  header files and record names use `formata_yaml` names. Original package
  namespaces have no compatibility aliases. YAML tag URIs remain unchanged
  because they identify serialized data formats.
- Reformatted with `mix format`.
- Compile-time optional integrations removed, because their presence would
  depend on the consumer's dependency tree: `Decimal` (Jason, Ymlr, JSON Schema
  `multipleOf`), `:idna` (JSON Schema `idn-hostname`), and the `Jason`/`JSON`
  selection in `backplane_json_schema` (Elixir's built-in `JSON` is used).
- No application environment: Jason's integer digit limit is fixed at 1024;
  yamerl's application callback, supervisor and global `node_mods` parameter
  are removed (node modules are passed per call).
- `gsmlg_toml`'s release configuration provider (`Toml.Provider`) is not
  included.
- Upstream moduledocs that were read from README files are replaced by
  `@moduledoc false`.

Bug fixes made in Formata after forking are listed in `CHANGELOG.md`.

## Formata additions to forked code

- `Formata.JSON.Backend` decoder: opt-in `comments` and `trailing_commas` decode
  options (default `false`), used by `Formata.Codec.JSON`.

## Original implementation

`Formata.Codec.TOML.Encoder` is an original implementation written against the
[TOML 1.0.0 specification](https://toml.io/en/v1.0.0).

`Formata.Codec.JSON.Stream` (written against
[RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)) and `Formata.Codec.JSON5`
(written against the [JSON5 1.0.0 specification](https://spec.json5.org/))
are original implementations; their test fixtures are written from those
specifications.

## Test fixtures

`test/fixtures/toml-test/` contains the TOML 1.0.0 valid and invalid cases
(`.toml` inputs and tagged-JSON expectations) from
[toml-lang/toml-test](https://github.com/toml-lang/toml-test) at commit
`96fd088448ec0f4d9f061c730ed7854399c46faf`, MIT licensed (Copyright (c) 2018
TOML authors). See `test/fixtures/toml-test/PROVENANCE.md` for the file list
and license text. Fixtures for the forked packages' own test suites are
described by the `PROVENANCE.md` file in each backend's `test/fixtures/`
directory. Test fixtures are not included in the Hex package.

`test/fixtures/yaml-test-suite/` contains 21 scoped leaf cases from the
official [YAML Test Suite](https://github.com/yaml/yaml-test-suite), pinned
to the generated `data-2022-01-17` release, commit
`6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`. They are MIT licensed,
Copyright (c) 2016-2020 Ingy döt Net. The selection, numbered subtests,
profile exclusions, and license are recorded in that directory's
`PROVENANCE.md` and `LICENSE`.
