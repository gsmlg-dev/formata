# Provenance: yamerl test fixtures

- Source: https://github.com/yakaz/yamerl
- Tag/commit: `v0.10.0` (`39981b9cb9d9edc227cf43a3e19dd16869493553`)
- License: BSD-2-Clause (Copyright (c) 2012-2014 Yakaz; Copyright (c) 2016-2022 Jean-Sébastien Pédron)
- Files: `{construction,examples,parsing,wrapper}/*.yaml` ← `test/{construction,examples,parsing,wrapper}/*.yaml`
- Modified: no (files copied byte-for-byte; only their location changed).
  The YAML tag URIs `tag:yamerl,2012:*` are yamerl's data format and are kept as-is.

The eunit modules that use these fixtures are in `test/formata/vendor/yamerl/eunit/`,
ported from the same tag's `test/**/*.erl`. Modified: module/record/atom names
renamed `yamerl*` → `formata_yamerl*` (test modules renamed
`formata_yamerl_SUITE_<dir>_<name>`), `FILENAME` paths pointed at this directory,
`application:start(yamerl)` setups replaced by `ok`, the node modules that
upstream set with `yamerl_app:set_param(node_mods, ...)` passed per call as
`{node_mods, ...}` (ipaddr, size, timestamp, erlang_atom, erlang_atom_if_exist,
erlang_atom_if_exist_auto, erlang_fun), and in `construction/float.erl` four
expectations for `"-0"` written as `-0.0` (OTP 27+ no longer matches `-0.0`
against the pattern `0.0`).
