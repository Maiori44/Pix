local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"

local fn finish_request(res, type, result, status_code) {
	if status_code {
		res.statusCode = status_code
	}
	res::setHeader("Content-Type", type)
	res::setHeader("Content-Length", #result)
	res::finish(result)
}

local fn read_file(res, type, path) {
	fs.readFile(path, fn(err, output) {
		assert(!err, output)
		finish_request(res, type, output)
	})
}

local patterns = {
	["^/$"] = fn(res) {
		read_file(res, "text/html", "src/index.html")
	}
	["(.+%.html)$"] = fn(res, name) {
		read_file(res, "text/html", "src" .. name)
	}
	["(.+%.css)$"] = fn(res, name) {
		read_file(res, "text/css", "src" .. name)
	}
}

http.createServer(fn(req, res) {
	local path = http.parseUrl(req.url).pathname
	for pattern, func of patterns {
		if local matched = path::match(pattern) {
			func(res, matched)
			return
		}
	}
})::listen(port, ip)
