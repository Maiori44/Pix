@define 

local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"

local index = assert(fs.readFileSync("src/index.html"))
local error = assert(fs.readFileSync("src/error.html"))
local style = assert(fs.readFileSync("src/style.css"))

local fn finish_request(res, type, result, status_code) {
	if status_code {
		res.statusCode = status_code
	}
	res::setHeader("Content-Type", type)
	res::setHeader("Content-Length", #result)
	res::finish(result)
}

local fn send_error(res, code, message) {
	finish_request(res, "text/html", error::format(code, message), code)
}

local patterns = {
	["^/$"] = fn {
		return "text/html", index
	}
	["^/style.css$"] = fn(res) {
		return "text/css", style
	}
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
