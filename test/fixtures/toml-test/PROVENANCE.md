# Vendored toml-test fixtures

- Source: https://github.com/toml-lang/toml-test (formerly BurntSushi/toml-test)
- Commit: `96fd088448ec0f4d9f061c730ed7854399c46faf`
  (2026-10-27, "Add more invalid dates and an invalid float case (#209)")
- Files: every `valid/**/*.json` entry listed in the upstream
  `tests/files-toml-1.0.0` manifest (208 tagged-JSON files, TOML 1.0.0 only;
  TOML 1.1.0-only cases are excluded). Paths are preserved relative to
  upstream `tests/`. The `.toml` inputs are not vendored; only the expected
  tagged-JSON values are used, by `test/formata/codec/toml_conformance_test.exs`.
- Files are unmodified copies.

## License

The MIT License (MIT)

Copyright (c) 2018 TOML authors

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
