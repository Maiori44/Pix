---init:
CREATE TABLE IF NOT EXISTS Files (
    uuid BLOB NOT NULL,
    filename TEXT NOT NULL,
    content_type TEXT,
    upload_date INTEGER,
    owner TEXT,
    PRIMARY KEY(uuid)
);
---get_info:
SELECT content_type, upload_date, owner FROM Files WHERE uuid = ?
---add_file:
INSERT INTO Files VALUES (?, ?, ?, ?, ?);
---