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
	["^/+(%a+%.html)$"] = fn(req, res, filename) {
		if assert_method(req, res, "GET") {
			return
		}
		if local cached = cache[filename] {
			finish_request(res, cached(req, res))
		} else {
			local ok, new = pcall(return_file, "text/html", "src/" .. filename)
			if !ok {
				send_error(res, 404, "Page not found.")
				return
			}
			cache[filename] = new
			finish_request(res, new(req, res))
		}
	}
	["^/+style%.css$"] = return_file("text/css", "src/style.css"),
	["^/+script%.js$"] = return_file("text/javascript", "src/script.js"),
	["^/+FSEX300%.ttf$"] = return_file("font/ttf", "FSEX300.ttf"),
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
			fs.readFile(".password", fn(err, password) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
					return
				}
				if decoded_data::get("password").value != password::match("[^\n]+") {
					send_error(res, 401, "Wrong password.")
					return
				}
				local file = decoded_data::get("file")
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
				return
			}
			finish_request(res, "image/png", file)
		})
	}
	["^/+storage_used$"] = fn(req, res) {
		fs.readdir("data", fn(err, files) {
			if err { //TODO print the error?
				send_error(res, 500, "Something unexpected happened.")
				return
			}
			local size = 0
			local tot_files = #files
			local fn read_file_size(err, file_info) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
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
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)
