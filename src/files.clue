@import "deps.sqlite3"

@define CONTENT_TYPE 1
@define UPLOAD_DATE 2
@define OWNER 3
@define EDIT_DATE 4
@define FLAGS 5

@define FLAG_UNLISTED 1
@define FLAG_FAVOURITE 2
@define FLAG_TEMPORARY 4

@macro get_all_steps(stmt) {
	local stmt = $stmt
	local result = {}
	loop {
		if local next = stmt::step() {
			table.insert(result, next)
		} else {
			return result
		}
	}
}

local fs = require("fs")

if !fs.existsSync("data") {
	fs.mkdirSync("data")
}

if !fs.existsSync("data/files") {
	fs.mkdirSync("data/files")
}

local files = sqlite3.open("data/data.db")
local all_codes = assert(fs.readFileSync("src/database.sql"))
local codes_reader = all_codes::gmatch("---([%a_]+):(.-)---")
local codes = {}

files::exec(select(2, codes_reader()))

for name, code with codes_reader {
	codes[name] = files::prepare(code)
}

local fn parse_uuid(filename) {
	local uuid = filename::match("^(%x+)-?")
	if !uuid || (#uuid != 32 && #uuid != 10) {
		return sqlite3.blob(filename)
	} elseif #uuid == 10 && tonumber(uuid) {
		return sqlite3.blob(uuid)
	}
	return sqlite3.blob(("I4I4I4I4")::pack(
		tonumber(uuid::sub(1, 8), 16),
		tonumber(uuid::sub(9, 16), 16),
		tonumber(uuid::sub(17, 24), 16),
		tonumber(uuid::sub(25, 32), 16)
	))
}

/*{
	local json = fs.readFileSync("data/files.json")
	if json {
		local add_file = codes.$
		local json = require("json").decode($)
		for k, v of json {
			local timestamp, filename = k::match("(%d+)-(.+)")
			add_file::reset()::bind(
				parse_uuid(k),
				filename || k,
				v.content_type || v,
				timestamp,
				v.owner
			)::step()
		}
		for truename with fs.scandirSync("data/files") {
			if !json[truename] {
				local timestamp, filename = truename::match("(%d+)-(.+)")
				add_file::reset()::bind(
					parse_uuid(truename),
					filename || truename,
					nil,
					timestamp
				)::step()
			}
		}
		fs.unlinkSync("data/files.json")
	}
}*/

local fn has_flags(flags, i, ...) {
	if local flag = select(i, ...) {
		return (flags & flag) != 0, has_flags(flags, i + 1, ...)
	}
}

return {
	get_info = fn(filename) {
		return codes.get_info::reset()::bind(parse_uuid(filename))::step() || {}
	}
	add_file = fn(uuid, filename, content_type, ip, flags) {
		codes.add_file::reset()::bind(
			sqlite3.blob(uuid),
			filename,
			content_type,
			os.time(),
			ip,
			flags
		)::step()
	}
	delete_file = fn(filename) {
		codes.delete_file::reset()::bind(parse_uuid(filename))::step()
	}
	replace_file = fn(filename, content_type) {
		codes.replace_file::reset()::bind(content_type, os.time(), parse_uuid(filename))::step()
	}
	has_flags = fn(filename, ...) {
		return has_flags(
			(type(filename) == "string")
				? (codes.get_flags::reset()::bind(parse_uuid(filename))::step()?[1] || 0)
				: filename,
			1,
			...
		)
	}
	get_flagged_files = fn(flags) {
		$get_all_steps!(codes.get_flagged_files::reset()::bind(flags))
	}
	get_file_list = fn() {
		$get_all_steps!(codes.get_file_list::reset())
	}
}
