.PHONY: fmt lint check test

fmt:
	cargo fmt

lint:
	cargo clippy -- -D warnings

check:
	cargo check

test:
	cargo test
