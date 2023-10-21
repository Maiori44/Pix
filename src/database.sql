---init:
CREATE TABLE IF NOT EXISTS Files (
	uuid BLOB NOT NULL,
	filename TEXT NOT NULL,
	content_type TEXT,
	upload_date INTEGER,
	owner TEXT,
	edit_date INTEGER,
	PRIMARY KEY(uuid)
);
---get_info:
SELECT content_type, upload_date, owner, edit_date FROM Files WHERE uuid = ?;
---add_file:
INSERT INTO Files VALUES (?, ?, ?, ?, ?, NULL);
---delete_file:
DELETE FROM Files WHERE uuid = ?;
---replace_file:
UPDATE Files SET content_type = ?, edit_date = ? WHERE uuid = ?;
---