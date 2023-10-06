local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"

local error_html = assert(fs.readFileSync("src/error.html"))

local fn finish_request(res, type, result, status_code) {
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

local fn return_file(type, path) {
	local file = assert(fs.readFileSync(path))
	return fn {
		return type, file
	}
}

local patterns = {
	["^/$"] = return_file("text/html", "src/index.html"),
	["^/style.css$"] = return_file("text/css", "src/style.css"),
	["^/FSEX300.ttf$"] = return_file("font/ttf", "FSEX300.ttf")
}

http.createServer(fn(req, res) {
	local path = http.parseUrl(req.url).pathname
	for pattern, func of patterns {
		if local matched = path::match(pattern) {
			finish_request(res, func(matched))
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)
