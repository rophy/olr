# Changes Over Upstream

This document tracks all source code changes in this fork (`rophy/olr`)
relative to upstream (`bersler/OpenLogReplicator`). Changes are categorized
to help assess merge conflict risk and identify candidates for upstream PRs.

Base: upstream v1.9.0 (merged at commit 5649d3b9, 2026-02-28)

---

## RAC Support (Phase 1-5)

Multi-thread redo log processing for Oracle RAC.

| Commit | Description | Files |
|--------|------------|-------|
| 2c79c0f0 | Phase 1: thread awareness in data structures | Parser, Metadata, Schema |
| f180920c | Phase 2: per-thread redo processing | Reader, Replicator |
| 629886f4 | Phase 3: SCN-ordered archive interleaving | Parser |
| 99d968e6 | Phase 4: online redo multi-thread parsing | Parser, Reader |
| 74889c2a | Phase 5a: batch mode multi-thread archive | Parser |
| f9e97a89 | Phase 5b: LWN-level archive interleaving | Parser |
| 139e60c3 | Phase 5c: fix mid-LWN yield SIGSEGV + memory leaks | Parser, TransactionBuffer, Ctx |

**Upstream PR candidate:** Yes — significant feature, well-tested

---

## Bug Fixes

| Commit | Description | Files | Issue |
|--------|------------|-------|-------|
| 5d34dc64 | float `setprecision(9)`, double `setprecision(17)` | BuilderJson.cpp | [#3](https://github.com/rophy/olr/issues/3) |
| 3f7b9d89 | float/double JSON output always includes decimal point | BuilderJson.cpp | [#4](https://github.com/rophy/olr/pull/4) |
| 521ad7db | NaN/Infinity → `null` in JSON (json-number-type=0) | BuilderJson.cpp | [#7](https://github.com/rophy/olr/issues/7) |
| 33102fba | subnormal float/double exponent off by 1 | Builder.cpp | [#5](https://github.com/rophy/olr/issues/5) |
| 1a2d316b | LOB INSERT preserved from phantom undo in streaming | Transaction.cpp | [#10](https://github.com/rophy/olr/issues/10) |
| ddf6bc04 | skip truncated URP null bitmap instead of abort | OpCode0504.cpp | — |
| 7cbd0580 | decode ROWID column type (type# 69) | Builder.cpp, SysCol.h, BuilderJson.* | [#15](https://github.com/rophy/olr/issues/15) |
| — | Reader status overwrite race during RAC archive transitions | Reader.cpp | [#14](https://github.com/rophy/olr/issues/14) |

**Upstream PR candidates:** All — these are correctness fixes

---

## Output Format Changes

Changes that affect OLR's JSON/Protobuf output format. These may impact
downstream consumers and should be carefully considered for upstream PRs.

| Commit | Change | Before | After | Risk |
|--------|--------|--------|-------|------|
| 5d34dc64 | float/double precision | Unspecified | float=9, double=17 digits | Low — more accurate |
| 3f7b9d89 | float/double format | `3` (no decimal) | `3.0` (always decimal) | Medium — format change |
| 521ad7db | NaN/Inf (type=0) | `NaN` (invalid JSON) | `null` | Low — fixes invalid JSON |
| 7cbd0580 | ROWID output | Not supported | Base64 (`AAASnuAAMAAAAKtAAA`) | None — new type |
| — | UROWID output | Hex (`030002ad.29ee.0000`) | **Unchanged** | None |

**Note:** ROWID (type 69, always physical) uses base64 — Oracle's standard
display format for physical row addresses. UROWID (type 208) keeps upstream's
hex format because UROWID can store logical ROWIDs (from IOTs) which have
variable length and are not the same 10-byte structure — base64 encoding
would be incorrect for those.

---

## Features

| Commit | Description | Files |
|--------|------------|-------|
| 4ab2ff4f | `char-set` format option to override charset decoding | Format.h, Builder.cpp |

---

## Not Changed (upstream only)

These upstream behaviors are preserved even though they could be improved:

- UROWID output uses hex format (`toHex`) — upstream choice, not changed to
  avoid fork divergence. See [#15](https://github.com/rophy/olr/issues/15)
  discussion.
