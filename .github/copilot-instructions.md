# Copilot Instructions — clawpass

clawpass is a Rust CLI tool that implements a session-scoped prompt handoff
queue backed by SQLite. It is part of the OpenClaw agent ecosystem.

## Key facts

- Single-file implementation: `src/main.rs` (~276 lines)
- Dependencies: clap 4 (derive), rusqlite 0.31 (bundled), chrono, serde/serde_json
- All output is JSON on stdout; errors/diagnostics on stderr
- Exit codes: 0=success, 1=validation, 2=empty/no-work, 3=storage error
- DB path: `~/.openclaw/clawpass.db` (override via `--db` or `CLAWPASS_DB`)
- Schema auto-creates on every run (`CREATE TABLE IF NOT EXISTS`)
- `pop` uses `BEGIN IMMEDIATE` transaction for atomicity

## When modifying this project

- Keep all logic in `src/main.rs` — no modules, no lib.rs
- Preserve the exit code contract (0/1/2/3)
- Preserve JSON output shapes — see `schemas/` for formal schemas
- `list` command constructs JSON via format string, not serde — update carefully
- `peek` reuses the `PopResult` struct with `popped_at: None`
- Timestamps use `chrono::Utc::now().to_rfc3339()` (nanosecond, `+00:00`)
- Update AGENTS.md, README.md, and schemas/ when changing the API contract
