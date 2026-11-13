# Scoped official YAML Test Suite fixtures

- Source: https://github.com/yaml/yaml-test-suite
- Generated data release: **`data-2022-01-17`**, annotated tag
  `5f49729577242103ae23838ac2ad4d9145aec126`, commit
  `6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`.
- Download: `https://codeload.github.com/yaml/yaml-test-suite/tar.gz/refs/tags/data-2022-01-17`.
- License: MIT, Copyright (c) 2016-2020 Ingy döt Net. `LICENSE` is the
  unmodified `License` file from the corresponding source release
  `v2022-01-17` (the generated data archive omits it).
- Selected directories are copied byte-for-byte, including `===`, input,
  output, event and error files where provided. No fixtures are downloaded
  during tests. The moving `data` branch is not used.

The 20 selected groups contain **21 leaf inputs**. `9MQT/00` and `9MQT/01`
are separate subtests, each with its own input/expected result. The harness
discovers `**/in.yaml` rather than treating parent directories as tests.

| Cases | Scope |
| --- | --- |
| `3GZX`, `JS2J`, `V55R`, `F2C7` | Anchors, aliases, explicit scalar tags |
| `A6F9`, `F8F9`, `K858`, `M9B4`, `R4YG`, `D83L` | Block scalar indentation and chomping |
| `G4RS`, `3UYS`, `6SLA`, `9MQT/00` | Escapes, quoted keys, multiline scalars |
| `55WF`, `HRE5`, `9MQT/01` | Invalid quoted escapes and document-marker boundary; syntax errors required |
| `2JQS` | Duplicate null keys; Formata requires `:duplicate_key` |
| `4FJ6`, `6BFJ` | Valid complex keys outside Formata's profile; explicit `:unsupported_key` required |
| `NKF9` | Multiple documents outside Formata's profile; explicit `:multiple_documents` required |

For the 14 ordinary valid cases, the upstream `in.json` expectations are
representable without type loss and are compared exactly. For complex/null
keys and multiple documents, upstream events remain available as evidence;
ordinary JSON dictionaries are not used as a key-semantics oracle. Policy
rejections are asserted tests, not skips. This is deliberately scoped
coverage, not a claim of passing the entire YAML Test Suite.

The upstream `error` marker takes precedence over other files in a leaf
case: `9MQT/01` includes an `in.json` but is marked as an invalid-input
test. It must not be treated as a passing semantic fixture.
