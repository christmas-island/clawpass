# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-26

Initial release.

### Added

- `push` command to insert prompts into a session queue.
- `pop` command with `BEGIN IMMEDIATE` transaction to prevent double-pop races.
- `peek` command to inspect the next prompt without consuming it.
- `list` command to show all pending prompts, optionally filtered by session.
- SQLite-backed storage with auto-created database and schema.
- Configurable database path via `--db` flag or `CLAWPASS_DB` env var.
- Structured JSON output on stdout for all commands.
- Defined exit codes: 0 (success), 1 (validation), 2 (empty), 3 (storage).

[0.2.0]: https://github.com/christmas-island/clawpass/releases/tag/v0.2.0
