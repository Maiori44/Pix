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
		return type, file
	}
}

local cache = {}

local patterns = {
	["^/+$"] = fn(_, res) {
		res::setHeader("Location", "index.html")
		return "text/plain", "Redirect to index.html", 303
	}
	["^/+(%a+%.html)$"] = fn(req, res, filename) {
		if assert_method(req, res, "GET") {
			return
		}
		if local cached = cache[filename] {
			return cached(req, res)
		} else {
			local ok, new = pcall(return_file, "text/html", "src/" .. filename)
			if !ok {
				send_error(res, 404, "Page not found.")
				return
			}
			cache[filename] = new
			return new(req, res)
		}
	}
	["^/+style%.css$"] = return_file("text/css", "src/style.css"),
	["^/+FSEX300%.ttf$"] = return_file("font/ttf", "FSEX300.ttf"),
	["^/+upload$"] = fn(req, res) {
		if assert_method(req, res, "POST") {
			return
		}
		local fields_data = {}
		req::on("data", fn(data) {
			table.insert(fields_data, data)
		})
		req::on("end", fn {
			print(table.concat(fields_data))
		})
		res::setHeader("Location", "waiting.html")
		return "text/plain", "Uploading...", 303
	}
}

http.createServer(fn(req, res) {
	local path = http.parseUrl(req.url).pathname
	for pattern, func of patterns {
		if local matched = path::match(pattern) {
			finish_request(res, func(req, res, matched))
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)
