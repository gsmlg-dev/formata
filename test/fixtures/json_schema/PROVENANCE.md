# Provenance: backplane_json_schema test suite

- Source: https://github.com/gsmlg-opt/backplane, `apps/backplane_json_schema/test`
- Tag/commit: `v1.10.76` (`8330b68740267beac2ce6dec01caafcccca4b207`). The
  tag's `apps/backplane_json_schema/lib` is identical to the Hex package
  `backplane_json_schema` 1.10.76 that `lib/formata/json_schema*` was
  forked from.
- License: Apache-2.0, declared in the package metadata (no license file or
  copyright notice is shipped upstream), see `LICENSES/Apache-2.0.txt`.
- Fixtures: none of its own. The conformance runner uses the official
  JSON-Schema-Test-Suite, vendored in `test/fixtures/JSON-Schema-Test-Suite`
  (see its PROVENANCE.md). This file records the provenance of the ported tests.
- Ported to `test/formata/json_schema/`
  (`test_helper.exs` not ported):
  - `uri_util_test.exs` ← `test/backplane/json_schema/uri_util_test.exs`
    (`Backplane.JsonSchema` → `Formata.JSONSchema`, module renamed
    `Formata.JSONSchema.URIUtilTest`).
  - `conformance_test.exs` ← `test/backplane/json_schema/conformance_test.exs`;
    the differences (one test per suite file, official fixture layout, remote
    mapping, Draft 7 added) are listed in the file's header comment.
  - Reformatted with `mix format`.
- Fork-specific regression tests are in
  `test/formata/json_schema/fork_fixes_test.exs` (not upstream).
