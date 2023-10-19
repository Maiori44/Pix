---init:
CREATE TABLE IF NOT EXISTS Files (
	FileName TEXT,
	ContentType TEXT,
	Owner TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS ui_filename ON Files (FileName);
---