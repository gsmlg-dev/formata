# Provenance: yaml_elixir test fixtures

- Source: https://github.com/KamilLelonek/yaml-elixir
- Tag/commit: `v2.12.2` (`4c5ee0408014a6e999dca4869e39eeca0e58a2c2`)
- License: MIT (Copyright (c) 2017 Kamil Lelonek)
- Files: `*.yml` ← `test/fixtures/*.yml` (used by `test/formata/vendor/yaml_elixir/yaml_elixir_test.exs`)
- Modified: no (files copied byte-for-byte; only their location changed).

`unclosed_flow.yml` is an additional Formata regression fixture, not an
upstream copy. It preserves the invalid-file tests after the original
`invalid.yml` (a lone `:`) was correctly recognized as a null-key/null-value
mapping. The original file remains unchanged and is tested as valid YAML.
