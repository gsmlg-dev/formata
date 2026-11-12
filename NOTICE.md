# Third-party notices

Formata's library code contains no copied or adapted third-party source.
`Formata.Codec.TOML.Encoder` is an original implementation written against the
[TOML 1.0.0 specification](https://toml.io/en/v1.0.0).

Runtime dependencies are used as published Hex packages under their own
licenses: `jason` (Apache-2.0), `gsmlg_toml` (Apache-2.0), `yaml_elixir` (MIT),
`yamerl` (BSD-2-Clause), `ymlr` (MIT), `backplane_schema` (MIT),
`backplane_json_schema` (Apache-2.0), `ex_json_pointer` (MIT).

## Test fixtures

`test/fixtures/toml-test/` contains unmodified tagged-JSON expectations from
[toml-lang/toml-test](https://github.com/toml-lang/toml-test) at commit
`96fd088448ec0f4d9f061c730ed7854399c46faf`, MIT licensed (Copyright (c) 2018
TOML authors). See `test/fixtures/toml-test/PROVENANCE.md` for the full
license text. Test fixtures are not included in the Hex package.
