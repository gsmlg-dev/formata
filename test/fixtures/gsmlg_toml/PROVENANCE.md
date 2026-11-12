# Vendored gsmlg_toml test fixtures

- Source: https://github.com/gsmlg-dev/gsmlg_umbrella, `apps/gsmlg_toml/test/fixtures/`
- Commit: `ce418646e3cb5f463eb7f863549c6de765821607` (2026-11-12, `main`)
- Files: everything under upstream `test/fixtures/` except `provider.toml`,
  which only serves the `Toml.Provider` tests (the provider is not forked).
  Paths are preserved relative to upstream `test/fixtures/`.
- Used by the ported tests in `test/formata/vendor/toml/`.

The parser and these historical fixtures derive from
[bitwalker/toml-elixir](https://github.com/bitwalker/toml-elixir); the
`toml-test/` subdirectory is adapted from an early (TOML 0.4/0.5)
[BurntSushi/toml-test](https://github.com/BurntSushi/toml-test).

## Modifications

Upstream recorded several expectations that matched decoder bugs rather than
the TOML specification. Formata fixed those bugs, so the affected expectations
were corrected (all checked against Python's `tomllib`):

- Offset date-times (gsmlg-dev/gsmlg_umbrella#13, inverted UTC offset sign):
  `example.json` (`datetime.key2`, `datetime.key3`), `valid/full.json` and
  `valid/readme-example.json` (`owner.dob`), `valid/date-time-2.json`,
  `valid/date-time-3.json`, `toml-test/valid/datetime.json` (`numoffset`,
  `milliseconds`), `toml-test/valid/datetime-timezone.json`.
- Line-ending backslash in multi-line basic strings must trim all following
  whitespace and newlines: `0.5.0.json` (`basicMultiline`), `example.json`
  (`string.multiline.continued.key2`), `valid/full.json` (`clients.str2`),
  `valid/string-basic-multiline-2.json`,
  `toml-test/valid/multiline-string.json` (`equivalent_two`).
- `-nan` decodes to `:nan` (the sign of NaN is implementation-defined and
  Formata has a single NaN value): `0.5.0.json` (`m_nan`),
  `valid/float-15.json`.
- `[[table] ]` and `[ [table]]` are invalid in TOML 1.0.0 (the brackets of an
  array-of-tables header must be adjacent):
  `toml-test/valid/{rrbrace,llbrace}.toml` moved to `toml-test/invalid/` and
  their `.json` expectations removed.

All other files are unmodified copies.

## License

Upstream `apps/gsmlg_toml/LICENSE` at that commit contains the Apache License
2.0 (inherited from bitwalker/toml-elixir) followed by this notice retained
from the gsmlg_toml 1.0.0 archive; the package metadata declares
`["Apache-2.0", "MIT"]`. The full Apache-2.0 text is in
`LICENSES/Apache-2.0.txt` at the repository root.

```
Copyright (c) 2022 Jonathan Gao

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
