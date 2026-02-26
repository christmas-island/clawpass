use chrono::Utc;
use clap::{Parser, Subcommand};
use rusqlite::{Connection, TransactionBehavior, params};
use serde::Serialize;
use std::path::PathBuf;
use std::process;

// Exit codes per contract
const EXIT_OK: i32 = 0;
const EXIT_VALIDATION: i32 = 1;
const EXIT_EMPTY: i32 = 2;
const EXIT_STORAGE: i32 = 3;

#[derive(Parser)]
#[command(name = "clawpass", version, about = "Session-scoped prompt handoff queue")]
struct Cli {
    /// Path to SQLite database (default: ~/.openclaw/clawpass.db)
    #[arg(long, env = "CLAWPASS_DB")]
    db: Option<PathBuf>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Push a prompt for a session
    Push {
        /// Session identifier
        session_id: String,
        /// Prompt text
        prompt: String,
    },
    /// Pop the next prompt for a session (returns and marks it consumed)
    Pop {
        /// Session identifier
        session_id: String,
    },
    /// Peek at the next prompt without consuming it
    Peek {
        /// Session identifier
        session_id: String,
    },
    /// List pending (unpopped) prompts, optionally filtered by session
    List {
        /// Filter by session identifier
        session_id: Option<String>,
    },
}

#[derive(Serialize)]
struct PushResult {
    ok: bool,
    session_id: String,
    created_at: String,
    id: i64,
}

#[derive(Serialize)]
struct PopResult {
    ok: bool,
    session_id: String,
    prompt: String,
    created_at: String,
    popped_at: Option<String>,
    id: i64,
}

#[derive(Serialize)]
struct EmptyResult {
    ok: bool,
    reason: String,
    session_id: String,
}

#[derive(Serialize)]
struct ListItem {
    id: i64,
    session_id: String,
    prompt: String,
    created_at: String,
}

fn db_path(cli_path: Option<PathBuf>) -> PathBuf {
    if let Some(p) = cli_path {
        return p;
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".openclaw").join("clawpass.db")
}

fn open_db(path: &PathBuf) -> Connection {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).ok();
    }
    let conn = Connection::open(path).unwrap_or_else(|e| {
        eprintln!("error: cannot open database: {e}");
        process::exit(EXIT_STORAGE);
    });
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS handoffs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            prompt TEXT NOT NULL,
            created_at TEXT NOT NULL,
            popped_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_clawpass_pending
            ON handoffs(session_id, popped_at, created_at, id);",
    )
    .unwrap_or_else(|e| {
        eprintln!("error: failed to initialize schema: {e}");
        process::exit(EXIT_STORAGE);
    });
    conn
}

fn main() {
    let cli = Cli::parse();
    let path = db_path(cli.db);
    let mut conn = open_db(&path);

    match cli.command {
        Commands::Push { session_id, prompt } => {
            if session_id.is_empty() {
                eprintln!("error: session_id must not be empty");
                process::exit(EXIT_VALIDATION);
            }
            if prompt.is_empty() {
                eprintln!("error: prompt must not be empty");
                process::exit(EXIT_VALIDATION);
            }
            let now = Utc::now().to_rfc3339();
            let id = match conn.execute(
                "INSERT INTO handoffs (session_id, prompt, created_at) VALUES (?1, ?2, ?3)",
                params![session_id, prompt, now],
            ) {
                Ok(_) => conn.last_insert_rowid(),
                Err(e) => {
                    eprintln!("error: {e}");
                    process::exit(EXIT_STORAGE);
                }
            };
            let result = PushResult { ok: true, session_id, created_at: now, id };
            println!("{}", serde_json::to_string(&result).unwrap());
        }

        Commands::Pop { session_id } => {
            let now = Utc::now().to_rfc3339();
            let tx = conn
                .transaction_with_behavior(TransactionBehavior::Immediate)
                .unwrap_or_else(|e| {
                    eprintln!("error: transaction: {e}");
                    process::exit(EXIT_STORAGE);
                });

            let result: Option<(i64, String, String)> = tx
                .query_row(
                    "SELECT id, prompt, created_at FROM handoffs
                     WHERE session_id = ?1 AND popped_at IS NULL
                     ORDER BY created_at ASC, id ASC LIMIT 1",
                    params![session_id],
                    |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
                )
                .ok();

            match result {
                Some((id, prompt, created_at)) => {
                    tx.execute(
                        "UPDATE handoffs SET popped_at = ?1 WHERE id = ?2",
                        params![now, id],
                    )
                    .unwrap_or_else(|e| {
                        eprintln!("error: {e}");
                        process::exit(EXIT_STORAGE);
                    });
                    tx.commit().unwrap_or_else(|e| {
                        eprintln!("error: commit: {e}");
                        process::exit(EXIT_STORAGE);
                    });
                    let out = PopResult {
                        ok: true, session_id, prompt, created_at,
                        popped_at: Some(now), id,
                    };
                    println!("{}", serde_json::to_string(&out).unwrap());
                }
                None => {
                    tx.commit().ok();
                    let out = EmptyResult {
                        ok: false,
                        reason: "empty".to_string(),
                        session_id: session_id.clone(),
                    };
                    println!("{}", serde_json::to_string(&out).unwrap());
                    eprintln!("no pending prompt for session {session_id}");
                    process::exit(EXIT_EMPTY);
                }
            }
        }

        Commands::Peek { session_id } => {
            let result: Option<(i64, String, String)> = conn
                .query_row(
                    "SELECT id, prompt, created_at FROM handoffs
                     WHERE session_id = ?1 AND popped_at IS NULL
                     ORDER BY created_at ASC, id ASC LIMIT 1",
                    params![session_id],
                    |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
                )
                .ok();

            match result {
                Some((id, prompt, created_at)) => {
                    let out = PopResult {
                        ok: true, session_id, prompt, created_at,
                        popped_at: None, id,
                    };
                    println!("{}", serde_json::to_string(&out).unwrap());
                }
                None => {
                    let out = EmptyResult {
                        ok: false,
                        reason: "empty".to_string(),
                        session_id: session_id.clone(),
                    };
                    println!("{}", serde_json::to_string(&out).unwrap());
                    process::exit(EXIT_EMPTY);
                }
            }
        }

        Commands::List { session_id } => {
            let items: Vec<ListItem> = if let Some(ref sid) = session_id {
                let mut stmt = conn.prepare(
                    "SELECT id, session_id, prompt, created_at FROM handoffs
                     WHERE session_id = ?1 AND popped_at IS NULL
                     ORDER BY created_at ASC, id ASC",
                ).unwrap();
                stmt.query_map(params![sid], |row| {
                    Ok(ListItem {
                        id: row.get(0)?,
                        session_id: row.get(1)?,
                        prompt: row.get(2)?,
                        created_at: row.get(3)?,
                    })
                })
                .unwrap()
                .filter_map(|r| r.ok())
                .collect()
            } else {
                let mut stmt = conn.prepare(
                    "SELECT id, session_id, prompt, created_at FROM handoffs
                     WHERE popped_at IS NULL
                     ORDER BY created_at ASC, id ASC",
                ).unwrap();
                stmt.query_map([], |row| {
                    Ok(ListItem {
                        id: row.get(0)?,
                        session_id: row.get(1)?,
                        prompt: row.get(2)?,
                        created_at: row.get(3)?,
                    })
                })
                .unwrap()
                .filter_map(|r| r.ok())
                .collect()
            };

            if items.is_empty() {
                println!("{{\"ok\":false,\"reason\":\"empty\"}}");
                process::exit(EXIT_EMPTY);
            }
            println!("{{\"ok\":true,\"items\":{}}}", serde_json::to_string(&items).unwrap());
        }
    }
}
