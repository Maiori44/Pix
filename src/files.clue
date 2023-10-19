@ifndef JSON {
	@import "deps.sqlite3"

	local fs = require("fs")

	local files = sqlite3.open("data/files.db")
	local all_codes = assert(fs.readFileSync("src/database.sql"))
	local codes = {}

	for name, code with all_codes::gmatch("---(%a+):(.-)---") {
		codes[name] = code
	}

	files::exec(codes.init)

	return {
		get_content_type = fn(filename) {
			
		}
		get_owner = fn(filename) {
			
		}
		add_file = fn(filename, file, ip = "0.0.0.0") {
			files::exec("")
		}
		remove_file = fn(filename) {
			
		}
	}
} @else {
	local json = require("json")
	local fs = require("fs")

	local files
	local json_file = fs.readFileSync("data/files.json")
	if json_file {
		files = json.decode(json_file)
	} else {
		files = {}
		fs.writeFileSync("data/files.json", "{}")
	}

	{	//this json library gives quite an awful output...let's fix it
		local encode = json.encode
		local state = {indent = true, exception = print}
		method json.encode(value) {
			return encode(value, state)::gsub("  ", "\t")::gsub("\"%:([{\"])", "\": %1")
		}
	}

	local fn save_json() {
		fs.writeFile("data/files.json", json.encode(files), fn(err) {
			if err {
				print(err)
			}
		})
	}

	return {
		get_content_type = fn(filename) {
			local file = files[filename] || "image/png"
			return file.content_type || file
		}
		get_owner = fn(filename) {
			return files[filename]?.owner
		}
		add_file = fn(filename, file, ip = "0.0.0.0") {
			files[filename] = {
				content_type = file.headers[2]::match("Content%-Type: (.+)")
				owner = ip
			}
			save_json()
		}
		remove_file = fn(filename) {
			files[filename] = nil
			save_json()
		}
	}
}
