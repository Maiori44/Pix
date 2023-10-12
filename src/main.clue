@import "src.multipart"

@macro assert_method(wanted) {
	if req.method != $wanted {
		send_error(res, 400, "Wrong request method.")
		return
	}
}

local pprint = require("pretty-print").prettyPrint
local querystring = require("querystring")
local http = require("http")
local json = require("json")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"
local error_html = assert(fs.readFileSync("src/error.html"))

local content_types
local json_file = fs.readFileSync("files.json")
if json_file {
	content_types = json.decode(json_file)
} else {
	content_types = {}
	fs.writeFileSync("files.json", "{}")
}

{	//this json library gives quite an awful output...let's fix it
	local encode = json.encode
	local state = {indent = true, exception = print}
	method json.encode(value) {
		return encode(value, state)::gsub("  ", "\t")::gsub("\"%:([{\"])", "\": %1")
	}
}

local fn finish_request(res, type, result, status_code) {
	if res.headersSent {
		return
	}
	if status_code {
		res.statusCode = status_code
	}
	res::setHeader("Content-Type", type)
	res::setHeader("Content-Length", #result)
	res::finish(result)
}

local fn send_error(res, code, message) {
	finish_request(res, "text/html", error_html::format(code, message), code)
}

local fn convert_bytes(bytes) {
	local sizes = {"B", "KB", "MB", "GB"}
    local i = 1
    while bytes >= 1000 && i < #sizes {
        bytes = bytes / 1000
        i += 1
    }
    return ("%.1f%s")::format(bytes, sizes[i])
}

local cache = {}

local patterns = {
	["^/+$"] = fn(_, res) {
		res::setHeader("Location", "index.html")
		finish_request(res, "text/plain", "Redirect to index.html", 303)
	}
	["^/+(%a+%.%a+)$"] = fn(req, res, filename) {
		$assert_method!("GET")
		if local cached = cache[filename] {
			finish_request(res, cached.type, cached.file)
		} else {
			fs.readFile("static/" .. filename, fn(err, file) {
				if err {
					send_error(res, 404, "File not found.")
					print(err)
					return
				}
				local type = match filename::match("%.(%a+)$") {
					"html" => "text/html",
					"js" => "text/javascript",
					"css" => "text/css",
					"ttf" => "font/tff",
					"ico" => "image/x-icon"
				}
				cache[filename] = {
					type = $
					file = $
				}
				finish_request(res, type, file)
			})
		}
	}
	["^/+upload$"] = fn(req, res) {
		$assert_method!("POST")
		local body_data = {}
		local size = 0
		req::on("data", fn(data) {
			size += #data
			if size >= 20000000 {
				send_error(res, 413, "File too large.")
				req::removeAllListeners()
				return
			}
			table.insert(body_data, data)
		})
		req::on("end", fn {
			local decoded_data = multipart(table.concat(body_data), req.headers["Content-Type"])
			local file = decoded_data::get("file")
			fs.readFile(".password", fn(err, password) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
					print(err)
					return
				}
				if decoded_data::get("password").value != password::match("[^\n]+") {
					send_error(res, 401, "Wrong password.")
					return
				}
				local filename = ("%d-%s")::format(os.time(), file.headers[1]::match("filename=\"(.+)\""))
				fs.writeFile("data/" .. filename, file.value, fn(err) {
					res::setHeader("Location", "/uploaded.html?file=" .. filename)
					finish_request(res, "text/plain", "Upload complete", 303)
				})
				content_types[filename] = file.headers[2]::match("Content%-Type: (.+)")
				fs.writeFile("files.json", json.encode(content_types), fn(err) {
					if err {
						print(filename .. ": " .. err)
					}
				})
			})
		})
	}
	["^/+files/+([^/]+)$"] = fn(req, res, filename) {
		$assert_method!("GET")
		fs.readFile("data/" .. filename, fn(err, file) {
			if err {
				send_error(res, 404, "File not found.")
				print(err)
				return
			}
			finish_request(res, content_types[filename] ?? "image/png", file)
		})
	}
	["^/+storage_used$"] = fn(req, res) {
		$assert_method!("GET")
		fs.readdir("data", fn(err, files) {
			if err {
				send_error(res, 500, "Something unexpected happened.")
				print(err)
				return
			}
			local size = 0
			local tot_files = #files
			local fn read_file_size(err, file_info) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
					print(err)
					tot_files = nil
					return
				}
				size += file_info.size
				tot_files -= 1
				if tot_files == 0 {
					finish_request(res, "text/plain", convert_bytes(size))
				}
			}
			for k, file in files {
				fs.stat("data/" .. file, read_file_size)
				if !tot_files {
					return
				}
			}
		})
	}
}

http.createServer(fn(req, res) {
	local path = http.parseUrl(req.url).pathname
	for pattern, func of patterns {
		if local matched = path::match(pattern) {
			func(req, res, matched)
			collectgarbage()
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)