# AGENTS.md — clawpass

> Maintenance: keep in sync with README.md, src/main.rs structs, and schemas/*.schema.json.

## Purpose

clawpass is a SQLite-backed CLI for session-scoped prompt handoff queues.
It lets one OpenClaw agent push a prompt for another agent's session, which
the receiving agent pops atomically. All output is JSON on stdout; diagnostics
go to stderr. Exit codes encode outcome semantics so shell scripts can branch
without parsing JSON.

## File tree

```
.
├── AGENTS.md                  # this file (LLM context)
├── README.md                  # human-oriented docs & behavior spec
├── Cargo.toml                 # crate metadata, deps (v0.2.0)
├── Cargo.lock                 # pinned dependency versions
├── src/
│   └── main.rs                # entire implementation (~276 lines)
├── schemas/                   # JSON Schema files for each command output
│   ├── push.schema.json
│   ├── pop.schema.json
│   ├── peek.schema.json
│   └── list.schema.json
└── .github/
    └── copilot-instructions.md
```

## Build / test / run

```bash
# build
cargo build --release

# install locally
cargo install --path .

# run (binary: clawpass)
clawpass push "session:1" "do the thing"
clawpass pop "session:1"
clawpass peek "session:1"
clawpass list                  # all sessions
clawpass list "session:1"      # one session

# override database path
clawpass --db /tmp/test.db push "s" "p"
CLAWPASS_DB=/tmp/test.db clawpass pop "s"

# no test suite yet — verify behavior manually via exit codes
clawpass pop "nonexistent"; echo "exit: $?"   # expect exit 2
```

## API contract

### Global flag

| Flag | Env var | Default | Description |
|------|---------|---------|-------------|
| `--db <path>` | `CLAWPASS_DB` | `~/.openclaw/clawpass.db` | SQLite database path |

### Commands

| Command | Args | Description |
|---------|------|-------------|
| `push <session_id> <prompt>` | both required, non-empty | Insert prompt; never mutates existing rows |
| `pop <session_id>` | required | Atomically return + soft-delete oldest pending row (`BEGIN IMMEDIATE`) |
| `peek <session_id>` | required | Return oldest pending row without modifying it |
| `list [session_id]` | optional | Return all pending rows; filter by session if provided |

### Exit codes

| Code | Constant | Meaning |
|------|----------|---------|
| `0` | `EXIT_OK` | Success, data returned on stdout |
| `1` | `EXIT_VALIDATION` | Bad input (empty session_id or prompt) |
| `2` | `EXIT_EMPTY` | No pending rows — normal "no work" condition |
| `3` | `EXIT_STORAGE` | Database open/write/transaction failure |

### JSON output shapes (stdout)

**push** (exit 0):
```json
{"ok":true,"session_id":"…","created_at":"2026-02-26T03:12:45.000000000+00:00","id":42}
```

**pop** success (exit 0):
```json
{"ok":true,"session_id":"…","prompt":"…","created_at":"…","popped_at":"…","id":42}
```

**pop** empty (exit 2):
```json
{"ok":false,"reason":"empty","session_id":"…"}
```

**peek** success (exit 0):
```json
{"ok":true,"session_id":"…","prompt":"…","created_at":"…","popped_at":null,"id":42}
```

**peek** empty (exit 2):
```json
{"ok":false,"reason":"empty","session_id":"…"}
```

**list** success (exit 0):
```json
{"ok":true,"items":[{"id":42,"session_id":"…","prompt":"…","created_at":"…"}]}
```

**list** empty (exit 2):
```json
{"ok":false,"reason":"empty"}
```

Note: `list` empty has no `session_id` field (unlike pop/peek empty).

### Timestamps

All timestamps are RFC 3339 via `chrono::Utc::now().to_rfc3339()` (nanosecond
precision, `+00:00` suffix — not `Z`).

## Architecture decisions

- **Single file**: everything is in `src/main.rs`. No library crate, no modules.
- **SQLite bundled**: `rusqlite` with `features = ["bundled"]` compiles SQLite
  from source — no system dependency required.
- **Schema auto-created**: `open_db()` runs `CREATE TABLE IF NOT EXISTS` and
  `CREATE INDEX IF NOT EXISTS` on every invocation. Safe to call concurrently.
- **Soft delete**: `pop` sets `popped_at` rather than deleting. Rows are never
  removed. This preserves audit trail but means the DB grows unboundedly.
- **Transaction isolation**: `pop` uses `BEGIN IMMEDIATE` to prevent two
  concurrent pops from returning the same row.
- **No async**: synchronous rusqlite. Appropriate for a CLI tool.
- **Serde for output**: push/pop/peek use `#[derive(Serialize)]` structs.
  `list` constructs JSON manually via format string for the outer wrapper.

## Common pitfalls

- **list JSON is hand-constructed**: the outer `{"ok":true,"items":…}` on
  line ~273 is a format string, not a Serialize struct. If you add fields,
  update the format string manually.
- **list empty has no session_id**: the empty response on line ~270 is a raw
  string literal `{"ok":false,"reason":"empty"}`, not the EmptyResult struct.
- **peek reuses PopResult struct**: peek returns a `PopResult` with
  `popped_at: None`. There is no separate PeekResult type.
- **Empty string validation**: only `push` validates that session_id and prompt
  are non-empty. `pop`, `peek`, and `list` accept empty strings (they just
  return no results).
- **DB directory creation**: `open_db()` calls `create_dir_all` on the parent
  directory. Failures are silently ignored (`.ok()`).
- **No purge command**: there is no way to delete old popped rows. The table
  grows forever.
