@import "src.multipart"

local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"
local error_html = assert(fs.readFileSync("src/error.html"))
local pprint = require("pretty-print").prettyPrint

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

local fn assert_method(req, res, wanted) {
	if req.method == wanted {
		return false
	}
	send_error(res, 400, "Wrong request method.")
	return true
}

local fn return_file(type, path) {
	local file = assert(fs.readFileSync(path))
	return fn(req, res) {
		assert_method(req, res, "GET")
		finish_request(res, type, file)
	}
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
		if assert_method(req, res, "GET") {
			return
		}
		if local cached = cache[filename] {
			finish_request(res, cached(req, res))
		} else {
			fs.readFile("static/" .. filename, fn(err, file) {
				if err {
					send_error(res, 404, "File not found.")
					print(err)
					return
				}
				local type = match filename::match("%.(%a+)$") {
					"css" => "text/css",
					"html" => "text/html",
					"js" => "text/javascript",
					"ttf" => "font/tff"
				}
				local fn new(req, res) {
					assert_method(req, res, "GET")
					finish_request(res, type, file)
				}
				cache[filename] = new
				finish_request(res, new(req, res))
			})
		}
	}
	["^/+upload$"] = fn(req, res) {
		if assert_method(req, res, "POST") {
			return
		}
		local body_data = {}
		req::on("data", fn(data) {
			table.insert(body_data, data)
		})
		req::on("end", fn {
			local decoded_data = multipart(table.concat(body_data), req.headers["Content-Type"])
			local file = decoded_data::get("file")
			if #file.value >= 20000000 {
				send_error(res, 413, "File too large.")
				return
			}
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
					res::setHeader("Location", "/files/" .. filename)
					finish_request(res, "text/plain", "Upload complete", 303)
				})
			})
		})
	}
	["^/+files/+([^/]+)$"] = fn(req, res, file) {
		fs.readFile("data/" .. file, fn(err, file) {
			if err {
				send_error(res, 404, "File not found.")
				print(err)
				return
			}
			finish_request(res, "image/png", file)
		})
	}
	["^/+storage_used$"] = fn(req, res) {
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