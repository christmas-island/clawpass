# Architecture

This document explains the design decisions and internals of clawpass.

## Overview

clawpass is a single-binary CLI that manages session-scoped prompt handoff queues. It is designed to be a coordination primitive for OpenClaw agents — one agent pushes work, another pops it.

```
┌────────────┐     push      ┌───────────────┐     pop      ┌────────────┐
│  Producer  │ ────────────► │   clawpass    │ ────────────► │  Consumer  │
│   Agent    │               │  (SQLite DB)  │               │   Agent    │
└────────────┘               └───────────────┘               └────────────┘
```

## Design Decisions

### Why SQLite?

- **Zero infrastructure** — no server to run, no ports to open, no auth to configure. The database is a single file.
- **ACID transactions** — `BEGIN IMMEDIATE` provides the serialization guarantee needed to prevent double-pop.
- **Bundled** — the `rusqlite` `bundled` feature compiles SQLite into the binary, so there are no system dependencies.
- **Good enough concurrency** — for the expected workload (low-frequency pops from a handful of agents), SQLite's file-level locking is sufficient.

### Why soft deletes?

Popped rows are not deleted. Instead, `popped_at` is set to the pop timestamp. This provides:

- **Audit trail** — you can see what was popped and when.
- **Debuggability** — if an agent misbehaves, you can inspect the full history.
- **Simplicity** — no need for a separate archive table or cleanup job (though one may be added later for large deployments).

### Why exit codes instead of just JSON?

Shell scripts need a fast way to branch on success vs. "no work" vs. "real error" without parsing JSON. The exit code contract makes this trivial:

```bash
if clawpass pop "$SID" > out.json; then
  # exit 0: got work
elif [ $? -eq 2 ]; then
  # exit 2: no work (normal)
else
  # exit 1 or 3: real problem
fi
```

### Why JSON on stdout only?

Separating machine output (stdout) from human diagnostics (stderr) lets scripts pipe stdout directly to `jq` or another tool without filtering out log noise.

### Why FIFO ordering?

Prompts are ordered by `(created_at ASC, id ASC)`. The `id` tiebreaker handles the (unlikely) case of two pushes in the same second. FIFO is the simplest correct ordering for a work queue.

## Code Structure

The project is a single file (`src/main.rs`) with no module hierarchy:

```
src/
└── main.rs        # CLI parsing, DB init, all command handlers
Cargo.toml         # Dependencies: clap, rusqlite, chrono, serde, serde_json
```

This is intentional. clawpass is small enough that a single file is easier to read and maintain than a multi-module layout. If the project grows (e.g., adding TTL expiration, garbage collection, or a watch mode), it should be split into modules.

### Key Components

| Component | Responsibility |
|-----------|---------------|
| `Cli` / `Commands` | clap-derived CLI parsing with `--db` flag and `CLAWPASS_DB` env support |
| `db_path()` | Resolves database path from flag → env → default (`~/.openclaw/clawpass.db`) |
| `open_db()` | Opens SQLite, creates parent dirs, runs `CREATE TABLE IF NOT EXISTS` and index |
| `Commands::Push` | Validates inputs, inserts row, returns JSON with new row ID |
| `Commands::Pop` | `BEGIN IMMEDIATE` transaction, selects oldest pending, sets `popped_at`, commits |
| `Commands::Peek` | Same query as pop but read-only, no transaction needed |
| `Commands::List` | Selects all pending rows, optionally filtered by session ID |

## Database Schema

```sql
CREATE TABLE handoffs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    prompt TEXT NOT NULL,
    created_at TEXT NOT NULL,
    popped_at TEXT
);

CREATE INDEX idx_clawpass_pending
    ON handoffs(session_id, popped_at, created_at, id);
```

### Index Design

The composite index `(session_id, popped_at, created_at, id)` is a covering index for the core query pattern:

```sql
SELECT id, prompt, created_at FROM handoffs
WHERE session_id = ? AND popped_at IS NULL
ORDER BY created_at ASC, id ASC
LIMIT 1
```

SQLite can satisfy this query entirely from the index without touching the table (except for the `prompt` column). The index also supports the `list` query's filter and ordering.

## Concurrency Model

clawpass uses SQLite's file-level locking with `BEGIN IMMEDIATE` for the `pop` command:

1. `BEGIN IMMEDIATE` acquires a reserved lock, preventing other writers.
2. The oldest pending row is selected.
3. `popped_at` is set on that row.
4. `COMMIT` releases the lock.

This prevents two concurrent `pop` calls from returning the same row. If a second `pop` arrives while the first holds the lock, SQLite will block (or return `SQLITE_BUSY`) until the first commits.

Read-only commands (`peek`, `list`) do not use explicit transactions and can run concurrently with each other.

## Future Considerations

- **TTL / expiration** — stale prompts could be auto-expired after a configurable duration.
- **Garbage collection** — a `gc` subcommand to delete old popped rows.
- **Watch mode** — `clawpass watch <session_id>` that blocks until a prompt is available, reducing poll frequency.
- **Module split** — if the codebase grows past ~500 lines, split into `db.rs`, `commands.rs`, `types.rs`.
