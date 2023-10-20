@import "deps.sqlite3"

local fs = require("fs")

local files = sqlite3.open("data/files.db")
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

return {
	get_info = fn(filename) {
		return codes.get_info::reset()::bind(parse_uuid(filename))::step()
	}
	add_file = fn(uuid, filename, content_type, ip = "0.0.0.0") {
		codes.add_file::reset()::bind(sqlite3.blob(uuid), filename, content_type, os.time(), ip)::step()
	}
	delete_file = fn(filename) {
		codes.delete_file::reset()::bind(parse_uuid(filename))::step()
	}
	replace_file = fn(filename, content_type) {
		codes.replace_file::reset()::bind(content_type, os.time(), parse_uuid(filename))::step()
	}
}

