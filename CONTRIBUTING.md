# Contributing to clawpass

Thanks for your interest in contributing to clawpass!

## Development Setup

```bash
git clone https://github.com/christmas-island/clawpass.git
cd clawpass
cargo build
cargo test
```

### Prerequisites

- Rust 1.70+ (stable)
- SQLite is bundled via `rusqlite`, no system install needed

### Pre-commit Hooks

Install [pre-commit](https://pre-commit.com/) and set up the hooks:

```bash
pip install pre-commit
pre-commit install
```

This runs formatting and lint checks before each commit.

You can also run checks manually:

```bash
cargo fmt --check
cargo clippy -- -D warnings
```

## Making Changes

### Branch Naming

Use descriptive branch names:

- `feat/add-ttl-support`
- `fix/pop-race-condition`
- `docs/improve-readme`

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <description>

[optional body]
```

Types:

| Type       | Use for                          |
|------------|----------------------------------|
| `feat`     | New features                     |
| `fix`      | Bug fixes                        |
| `docs`     | Documentation only               |
| `refactor` | Code changes that aren't fixes   |
| `test`     | Adding or updating tests         |
| `chore`    | Build, CI, tooling changes       |

Examples:

```
feat: add TTL expiration for stale prompts
fix: prevent double-pop under concurrent access
docs: add architecture decision record
```

### Pull Request Process

1. Fork the repo and create your branch from `main`.
2. Make your changes with tests where applicable.
3. Ensure all checks pass: `cargo test && cargo clippy -- -D warnings && cargo fmt --check`
4. Open a PR against `main` with a clear description of what and why.
5. A maintainer will review your PR. Address any feedback.

### PR Checklist

- [ ] Tests pass (`cargo test`)
- [ ] No clippy warnings (`cargo clippy -- -D warnings`)
- [ ] Code is formatted (`cargo fmt`)
- [ ] Commit messages follow conventional commits
- [ ] README or docs updated if behavior changed

## Testing

### Running Tests

```bash
# All tests
cargo test

# Specific test
cargo test test_push_pop

# With output
cargo test -- --nocapture
```

### Writing Tests

- Test the CLI exit codes and JSON output contract.
- Use a temporary database path (`--db /tmp/test_xxx.db`) to avoid interfering with real data.
- Cover both success and error paths.

## Questions?

Open an issue on the [GitHub repo](https://github.com/christmas-island/clawpass/issues).
