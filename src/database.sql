---init:
CREATE TABLE IF NOT EXISTS Files (
	FileName TEXT,
	ContentType TEXT,
	Owner TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS ui_filename
ON Files (FileName);
---get:
SELECT %s
FROM Files
WHERE FileName = '%s'
---add_file:
INSERT INTO Files
VALUES ('%s', '%s', '%s');
---