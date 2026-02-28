# clawpass

<!-- Badges -->
[![CI](https://github.com/christmas-island/clawpass/actions/workflows/ci.yml/badge.svg)](https://github.com/christmas-island/clawpass/actions/workflows/ci.yml)
[![Crate Version](https://img.shields.io/crates/v/clawpass)](https://crates.io/crates/clawpass)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Session-scoped prompt handoff queue for [OpenClaw](https://github.com/christmas-island) agents. Backed by SQLite.

## Features

- **Session-scoped queues** — prompts are isolated by session ID, so multiple agents can share one database without interference.
- **FIFO ordering** — `pop` always returns the oldest pending prompt.
- **Race-safe pop** — uses `BEGIN IMMEDIATE` transactions to prevent double-pop under concurrent access.
- **Soft deletes** — popped rows are marked with `popped_at` rather than deleted, preserving an audit trail.
- **JSON-only stdout** — all output is machine-readable JSON; human diagnostics go to stderr.
- **Defined exit codes** — scripts can branch reliably on exit status (0/1/2/3).
- **Zero config** — works out of the box with a default database path; no server needed.

## Install

### Quick install (Linux / macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/christmas-island/clawpass/main/install.sh | sh
```

Override the install directory:

```bash
CLAWPASS_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/christmas-island/clawpass/main/install.sh | sh
```

### Homebrew

```bash
brew tap christmas-island/tap
brew install clawpass
```

### cargo binstall

```bash
cargo binstall clawpass
```

### cargo install

```bash
cargo install clawpass
```

### Manual download

Pre-built binaries for Linux (x86_64, aarch64), macOS (x86_64, Apple Silicon), and Windows (x86_64) are available on the [GitHub Releases](https://github.com/christmas-island/clawpass/releases) page. Each archive includes a `.sha256` checksum file.

### From releases

Download a prebuilt binary from the [GitHub Releases](https://github.com/christmas-island/clawpass/releases) page, extract it, and place it on your `PATH`:

```bash
curl -fsSL https://github.com/christmas-island/clawpass/releases/latest/download/clawpass-$(uname -s)-$(uname -m).tar.gz \
  | tar xz -C /usr/local/bin
```

## Usage

```bash
clawpass push <session_id> <prompt>
clawpass pop <session_id>
clawpass peek <session_id>
clawpass list [session_id]
```

### Quick Example

```bash
# Push a prompt for a session
clawpass push "agent:main:discord:123" "summarize the last 10 messages"

# Pop the next prompt (returns it and marks consumed)
clawpass pop "agent:main:discord:123"

# Peek without consuming
clawpass peek "agent:main:discord:123"

# List all pending prompts
clawpass list

# List pending prompts for a specific session
clawpass list "agent:main:discord:123"
```

## Configuration

| Setting | Flag | Env var | Default |
|---------|------|---------|---------|
| Database path | `--db <path>` | `CLAWPASS_DB` | `~/.openclaw/clawpass.db` |

The database file and parent directories are created automatically on first use.

### Session ID Conventions

Session IDs are arbitrary strings. The recommended convention is a colon-delimited path:

```
agent:<agent_name>:<platform>:<channel_or_context>:<id>
```

Examples: `agent:main:discord:channel:123`, `agent:worker:slack:thread:456`

## Behavior Spec (v0.2)

### Commands

- **`push`** — Insert a prompt for a session. Never mutates existing rows.
- **`pop`** — Return the oldest pending row and set `popped_at` (soft delete). Runs in `BEGIN IMMEDIATE` transaction to prevent double-pop races.
- **`peek`** — Return the oldest pending row without modifying it.
- **`list`** — Return all pending rows, optionally filtered by session.

### Exit Codes

| Code | Meaning |
|------|---------|
| `0`  | Success / data returned |
| `1`  | Validation / usage error |
| `2`  | Empty / not found (normal no-work condition) |
| `3`  | Storage / database error |

### Output Contract

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

### Shell Usage Pattern

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

## Development

### Prerequisites

- Rust toolchain (rustup)
- [pre-commit](https://pre-commit.com/) (`pip install pre-commit` or `brew install pre-commit`)

### Setup

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

### Make targets

```bash
make fmt    # run rustfmt
make lint   # run clippy with -D warnings
make check  # run cargo check
make test   # run cargo test
```

### Commit conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Commit messages are enforced by a pre-commit hook.

Examples:
```
feat: add queue priority support
fix: handle empty session_id in pop
docs: update README with dev setup
chore: bump dependencies
```

## Troubleshooting

### `error: cannot open database`

The database path is not writable, or the parent directory doesn't exist and can't be created.

- Check permissions on the directory: `ls -la ~/.openclaw/`
- Try an explicit path: `clawpass --db /tmp/test.db list`

### `error: session_id must not be empty`

You passed an empty string as the session ID. Make sure to quote your arguments:

```bash
clawpass push "$SESSION_ID" "$PROMPT"
```

### Pop returns exit code 2 but I expected data

Exit code 2 means the queue is empty for that session. This is a normal "no work" condition, not an error. Check your session ID matches what was used for `push`.

### Database locked errors under concurrency

clawpass uses `BEGIN IMMEDIATE` for `pop` to serialize concurrent access. If you see locking errors, ensure you're not holding long-lived connections to the same database from another process. SQLite handles short transactions well but is not designed for high-concurrency workloads.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for design decisions and internals.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[MIT](LICENSE)
