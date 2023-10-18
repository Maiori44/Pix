local json = require("json")
local fs = require("fs")

local files
local json_file = fs.readFileSync("files.json")
if json_file {
	files = json.decode(json_file)
} else {
	files = {}
	fs.writeFileSync("files.json", "{}")
}

{	//this json library gives quite an awful output...let's fix it
	local encode = json.encode
	local state = {indent = true, exception = print}
	method json.encode(value) {
		return encode(value, state)::gsub("  ", "\t")::gsub("\"%:([{\"])", "\": %1")
	}
}

local fn save_json() {
	fs.writeFile("files.json", json.encode(files), fn(err) {
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
	add_file = fn(filename, file, req) {
		files[filename] = {
			content_type = file.headers[2]::match("Content%-Type: (.+)")
			owner = req.socket::address().ip
		}
		save_json()
	}
	remove_file = fn(filename) {
		files[filename] = nil
		save_json()
	}
}