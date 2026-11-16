# Provenance: backplane_schema test suite

- Source: https://github.com/gsmlg-opt/backplane, `apps/backplane_schema/test`
- Tag/commit: `v1.10.76` (`8330b68740267beac2ce6dec01caafcccca4b207`). The
  tag's `apps/backplane_schema/lib` is identical to the Hex package
  `backplane_schema` 1.10.76 that `lib/formata/native_schema*` was forked from.
- License: MIT (Copyright 2024 zoedsoupe; Copyright 2026 Backplane
  Contributors), see `LICENSES/backplane_schema.txt`.
- Fixtures: none; the upstream tests use no data files. This file records the
  provenance of the ported tests.
- Ported to `test/formata/native_schema_test.exs` and
  `test/formata/native_schema/`, following the current module names and
  directory structure (`test_helper.exs` not ported). Modifications:
  - `Backplane.Schema` → `Formata.NativeSchema`; `Jason` → `Formata.JSON.Backend` (the
    fork derives `Formata.JSON.Backend.Encoder`).
  - Test modules renamed into `Formata.NativeSchema.*`
    (`PeriTest` → `Formata.NativeSchemaTest`); expected JSON Schema
    definition names derived from those module names
    (`Backplane_Schema_RefTest_…` → `Formata_NativeSchema_RefTest_…`)
    follow the rename.
  - `performance_phase2_test.exs`: the permissive-mode assertions that pinned
    gsmlg-opt/backplane#171 (converted values duplicated under atom keys) are
    replaced by an assertion of the complete, non-duplicated result.
  - Reformatted with `mix format`.
- Fork-specific regression tests are in
  `test/formata/native_schema/fork_fixes_test.exs` (not upstream).
