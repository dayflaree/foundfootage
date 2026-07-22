PRAGMA foreign_keys = ON;

CREATE TABLE messages (
    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT NOT NULL UNIQUE,
    map_name TEXT NOT NULL,
    author_steamid64 TEXT NOT NULL,
    body TEXT NOT NULL,
    position_x REAL NOT NULL,
    position_y REAL NOT NULL,
    position_z REAL NOT NULL,
    normal_x REAL NOT NULL,
    normal_y REAL NOT NULL,
    normal_z REAL NOT NULL,
    created_at INTEGER NOT NULL,
    deleted_at INTEGER
);

CREATE INDEX messages_map_sequence
    ON messages(map_name, sequence);
CREATE INDEX messages_author_map_active
    ON messages(author_steamid64, map_name, deleted_at);
CREATE INDEX messages_author_created
    ON messages(author_steamid64, created_at);

CREATE TABLE message_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    map_name TEXT NOT NULL,
    message_id TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('create', 'delete')),
    created_at INTEGER NOT NULL
);

CREATE INDEX message_events_map_cursor
    ON message_events(map_name, event_id);

CREATE TABLE auth_tickets (
    ticket TEXT PRIMARY KEY,
    steamid64 TEXT,
    created_at INTEGER NOT NULL,
    completed_at INTEGER
);

CREATE INDEX auth_tickets_created
    ON auth_tickets(created_at);

CREATE TABLE sessions (
    token_hash TEXT PRIMARY KEY,
    steamid64 TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL
);

CREATE INDEX sessions_steamid64
    ON sessions(steamid64);
CREATE INDEX sessions_expiry
    ON sessions(expires_at);

CREATE TABLE mutes (
    steamid64 TEXT PRIMARY KEY,
    reason TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER
);

CREATE TABLE reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT NOT NULL,
    reporter_steamid64 TEXT NOT NULL,
    reason TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE(message_id, reporter_steamid64)
);

CREATE INDEX reports_message
    ON reports(message_id);
