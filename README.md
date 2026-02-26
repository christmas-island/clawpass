# clawpass

Session-scoped prompt handoff queue for OpenClaw agents. Backed by SQLite.

## Install

```bash
cargo install --path .
```

Binary installs to `~/.cargo/bin/clawpass`.

## Usage

```bash
clawpass push <session_id> <prompt>
clawpass pop <session_id>
clawpass peek <session_id>
clawpass list [session_id]
```

Override database path with `--db <path>` or `CLAWPASS_DB` env var.  
Default: `~/.openclaw/clawpass.db`

## Behavior Spec (v0.2)

### Commands

- **`push`** — Insert a prompt for a session. Never mutates existing rows.
- **`pop`** — Return the oldest pending row and set `popped_at` (soft delete). Runs in `BEGIN IMMEDIATE` transaction to prevent double-pop races.
- **`peek`** — Return the oldest pending row without modifying it.
- **`list`** — Return all pending rows, optionally filtered by session.

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success / data returned |
| `1`  | Validation / usage error |
| `2`  | Empty / not found (normal no-work condition) |
| `3`  | Storage / database error |

### Output contract

- **stdout:** JSON only (machine-readable)
- **stderr:** diagnostics/errors only (human-readable)

#### `push` success (`0`)
```json
{"ok":true,"session_id":"agent:main:discord:channel:123","created_at":"2026-02-26T03:12:45Z","id":42}
```

#### `pop` success (`0`)
```json
{"ok":true,"id":42,"session_id":"agent:main:discord:channel:123","prompt":"do the thing","created_at":"2026-02-26T03:12:45Z","popped_at":"2026-02-26T03:13:02Z"}
```

#### `pop` empty (`2`)
```json
{"ok":false,"reason":"empty","session_id":"agent:main:discord:channel:123"}
```

#### `peek` success (`0`)
```json
{"ok":true,"id":42,"session_id":"agent:main:discord:channel:123","prompt":"do the thing","created_at":"2026-02-26T03:12:45Z","popped_at":null}
```

#### `list` success (`0`)
```json
{"ok":true,"items":[{"id":42,"session_id":"agent:main:discord:channel:123","prompt":"do the thing","created_at":"2026-02-26T03:12:45Z"}]}
```

#### `list` empty (`2`)
```json
{"ok":false,"reason":"empty"}
```

### Storage

Default database path: `~/.openclaw/clawpass.db`

Schema: `handoffs(id, session_id, prompt, created_at, popped_at)`

Index: `idx_clawpass_pending ON handoffs(session_id, popped_at, created_at, id)`

### Shell usage pattern

```bash
if clawpass pop "$SESSION_ID" > /tmp/handoff.json; then
  PROMPT=$(jq -r '.prompt' /tmp/handoff.json)
  # do work with $PROMPT
else
  code=$?
  if [ "$code" -eq 2 ]; then
    # no work available
    exit 0
  fi
  # real failure
  exit "$code"
fi
```

## License

MIT
