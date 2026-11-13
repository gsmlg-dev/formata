# TOML correctness review

Reviewed on 2026-11-13 against TOML 1.0.0. The supplied review baseline was
`b6d1bba0e771f5f413b4d3ce7f35b01049575746`; execution started from clean `main`
at `735ae8db1f089ab0e7532470cce044cd3a2dcc9f` (Formata 0.3.0). Newer JSON
work was retained. The maintenance target is Formata's internal fork, with
the existing single Mix library, API, and parser architecture; no runtime
dependency or TOML 1.1 syntax was added.

## Findings and fixes

All four residual findings reproduced on the starting checkout, even though
the existing TOML codec/conformance command passed 1151 tests.

| Finding | Reproduction before the fix | Resolution and regression |
| --- | --- | --- |
| A: comment before assignment value | `a = # comment\n1` decoded as `%{"a" => 1}`; `a = { k = # comment\n1 }` also succeeded | The lexer preserves comment-ending newlines as separate tokens, and `value/1` no longer skips comments. Arrays retain their own comment/newline handling, while assignments and inline key/value pairs require a value immediately after horizontal whitespace. LF/CRLF, EOF comments, trailing comments, multiline arrays and strings inside inline tables are covered. |
| B: underscore after exponent sign | `1e+_2`, `1e-_2`, `1.0e+_2` decoded as `100.0`, `0.01`, `100.0` | Only actual digit tokens can precede underscores, and the following token must also contain digits before normalization removes the underscore. Fraction/exponent completion requires digits; incomplete input returns syntax errors. Tests combine signs, `e`/`E`, fractions, underscores and valid controls. |
| C: date-time separator | An actual tab or two spaces between `2024-01-01` and `12:00:00` decoded as a local date-time | Whitespace tokens retain their text; only exactly one ASCII space can join date and time (alongside `T`/`t`). Date-only trailing whitespace is still legal. Local/offset datetimes and root/array/inline terminators are covered. |
| D: invalid UTF-8 keys | Both `Formata.encode(%{<<0xFF>> => 1}, :toml)` and `Encoder.encode/1` raised `FunctionClauseError` in `escape/2` | Shared domain validation rejects invalid UTF-8 binary keys before rendering. Errors use `:encode` / `:invalid_key`, the containing-map path, and `details.key`. Root, nested, array-of-table and inline-map layouts cover TOML and the affected JSON/JSON5/YAML codecs. Valid Unicode, empty and escaped keys remain accepted. |

Focused regressions are in `test/formata/codec/toml_boundary_test.exs` and
`test/formata/codec/encoding_keys_test.exs`. They exercise direct decoder/
encoder calls and the public facade. Invalid grammar asserts the low-level
`:invalid_toml` result and public `:parse` / `:syntax` errors with source
locations; encoding errors assert paths and key details. No broad rescue was
added.

Boundary minimization also exposed `a =\r\n1`: the error formatter subtracted
two bytes from a one-byte remaining CRLF position and failed internally.
The CRLF boundary guard now handles both bytes. The regression asserts a
structured syntax error and retains the decoder's existing convention for a
bare newline token: column zero on the following line. Comment errors point
to the comment's own line, before its separately tokenized newline.

## Historical issues: Formata versus the old package

Read-only inspection of `gsmlg-dev/gsmlg_umbrella` on 2026-11-13 found its
HEAD still at `ce418646e3cb5f463eb7f863549c6de765821607`. The five issues
remain open. Its source still lacks the following Formata behavior; no old
package build or publication was performed in this review.

| Old issue | Formata disposition | Old repository disposition |
| --- | --- | --- |
| [#12](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/12) | Existing public TOML encoding retained, including conformance round-trips | `Toml` delegates only decode operations; adding an encoder or migrating consumers to Formata remains necessary. |
| [#13](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/13) | Existing positive/negative nonzero offset tests pass; UTC = local - offset | Old `datetime/3` still subtracts negative offsets and adds positive ones; backport or migrate. |
| [#14](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/14) | Existing multiple-empty-element/order/nested-subtable tests pass | Old builder still starts arrays of tables with `[]`, unlike Formata's explicit empty element and nested insertion handling; backport or migrate. |
| [#15](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/15) | Existing boolean-looking key contexts and strict boolean-value tests pass | Old key token guards omit `true`/`false`; backport or migrate. |
| [#16](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/16) | Existing local datetime comma/closing-bracket/closing-brace tests pass | Old local-datetime terminators include only EOF/whitespace/newline; backport or migrate. |

These named regressions remain unchanged in `test/formata/codec/toml_test.exs`.
Fixes in Formata do not close the old issues or establish that an old package
release is fixed. The new A-C parser changes likewise live in this fork; D
protects Formata's encoders.

## Conformance and reference limits

The fixture corpus and provenance are unchanged: 208 valid and 509 invalid
TOML 1.0.0 inputs pinned to `toml-test`
`96fd088448ec0f4d9f061c730ed7854399c46faf`. All exclusion/known-failure maps
remain empty. Existing semantic comparisons and independent Python `tomllib`
encoder validation remain enabled in CI.

The new differential decoder checks use deterministic boundary combinations
with specification-derived expected results. They compare acceptance and
normalized semantic values, rather than adopting a reference parser's
acceptance as the specification. Python checks stay within its representable
calendar/numeric range: Python dates cannot represent year 0000. Offset
datetimes compare after UTC normalization; fractional seconds truncate to six
digits; special floats normalize to Formata's atoms. NaN sign and the original
UTC offset are not preserved. TOML remains 1.0.0, and source formatting,
comments and key order are not retained.

Python 3.15's `tomllib` also accepts the TOML 1.1 inline-table comment/newline
extension. The differential test detects that reference capability and checks
its known semantic result for exactly the two LF/CRLF extension cases (or
syntax rejection on older Python). Formata must still reject both cases;
all other differential expectations remain strict. CI uses Python 3.12.

## Validation

The repository has no Nix/devenv configuration. Local validation uses the
installed Elixir 1.20.4 / Erlang OTP 28 (ERTS 16.4.0.1), Python 3.15.2, and
the installed Elixir 1.18.4-otp-28 for the minimum supported version.

Executed commands and results:

| Command | Result |
| --- | --- |
| `mix test test/formata/codec/toml_test.exs test/formata/codec/toml_conformance_test.exs` (before edits) | 1151 passed; no skips |
| `mix test test/formata/codec/encoding_keys_test.exs test/formata/codec/json_test.exs test/formata/codec/json5_test.exs test/formata/codec/yaml_test.exs test/formata/codec/toml_test.exs` | 71 passed |
| `mix test test/formata/codec/toml_boundary_test.exs test/formata/codec/toml_test.exs test/formata/codec/toml_conformance_test.exs test/formata/vendor/toml` | 1470 passed; no skips; 173 valid and 293 invalid boundary documents |
| `mix deps.get` | Passed; lockfile unchanged |
| `mix format --check-formatted` | Passed |
| `MIX_ENV=test mix compile --warnings-as-errors --force` | Passed on Elixir 1.20.4 and 1.18.4 |
| `mix test` | Both versions: 3570 passed, 1 existing YMLR skip; no failures |
| `mix docs --warnings-as-errors` | Passed after correcting the review's provenance link |
| `mix hex.build` | Passed at the pre-release version; release workflow owns the version bump |
| `mix hex.build --unpack -o /tmp/formata-toml-audit-package` | Passed |
| Isolated consumer: `mix deps.get && mix run smoke.exs` | Passed with no runtime dependencies; exercises all four fixes and Unicode/inline-map round-trip |
| `git diff --check` | Passed; fixtures, conformance harness, historical tests, lockfile and CI workflows unchanged |

The 1.18 commands used
`PATH=/Users/gao/.local/share/mise/installs/elixir/1.18.4-otp-28/bin:$PATH`
and `MIX_BUILD_PATH=/tmp/formata-toml-audit-elixir118` to isolate compiled
artifacts. Tests ran serially because the conformance harness shares a
temporary output directory. The full suite's single skip is the unchanged
vendored YMLR `multiline strings - starting with spaces` test. Test-time
warnings in the unchanged Jason/YMLR test modules were reported; library
compilation with warnings treated as errors passed on both versions.

The next release is 0.3.1 through the existing manual-dispatch Release
workflow, which performs its own version bump, gate, commit, tag and Hex/
GitHub publication. No manual duplicate version bump or tag is required.

## References

- [TOML 1.0.0](https://toml.io/en/v1.0.0): key/value pairs, float underscores,
  date-time separators, arrays and inline-table newline rules.
- [Fixture provenance](https://github.com/gsmlg-dev/formata/blob/main/test/fixtures/toml-test/PROVENANCE.md).
- [Release procedure](release.md).
