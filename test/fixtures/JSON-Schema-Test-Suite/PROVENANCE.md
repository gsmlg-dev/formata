# Provenance: JSON-Schema-Test-Suite

- Source: https://github.com/json-schema-org/JSON-Schema-Test-Suite
- Commit: `5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8` — the commit pinned by
  backplane_json_schema 1.10.76 (`@suite_commit` in its
  `test/backplane/json_schema/conformance_test.exs`; upstream keeps its copy in
  `apps/backplane_agent_runtime/test/fixtures/json_schema_test_suite`).
- License: MIT (text below).
- Files (official repository layout, copied byte-for-byte; only their location changed):
  - `tests/draft2020-12/*.json` ← `tests/draft2020-12/*.json` (required tests only; `optional/` is not included)
  - `tests/draft7/*.json` ← `tests/draft7/*.json` (required tests only; `optional/` is not included)
  - `remotes/**` ← `remotes/**`, without the `draft3`, `draft4`, `draft6`,
    `draft2019-09` and `v1` subdirectories, which no included test references
  - `COMMIT` — the commit above (written for the runner, not part of the suite)
- Used by: `test/formata/json_schema/conformance_test.exs`.

## License

```
Copyright (c) 2012 Julian Berman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
