# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0]

### Added

- JSON (`jason`), TOML (`gsmlg_toml` decoder, built-in TOML 1.0.0 encoder), and
  single-document YAML (`yaml_elixir` / `ymlr`) codecs with a documented
  portable value domain, duplicate-key rejection, and strict encoding that
  rejects unrepresentable values.
- `Formata.convert/4` with explicit transformations (`Formata.Transform`).
- Native schemas (`Backplane.Schema`) with pure validation (`validate/3`) over
  a checked non-transforming subset, unknown-field allow/reject, and full
  casting (`cast/3`) with defaults, coercion, transforms, and stripping.
- JSON Schema Draft 7 and Draft 2020-12 (`Backplane.JsonSchema`) with dialect
  selection, local references, explicit remote loaders, and configurable
  format assertion.
- Structured `Formata.Error` values for parse, encode, schema, validation,
  transform, and unsupported-operation failures.
