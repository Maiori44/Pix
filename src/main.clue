@import "deps.multipart"
@import "files"

@macro assert_method(wanted) {
	if req.method != $wanted {
		send_error(res, 400, "Wrong request method.")
		return
	}
}

@macro assert_password(code, ...) {
	local body_data = {}
	req::on("data", fn(data) {
		${$vararg}
		table.insert(body_data, data)
	})
	req::on("end", fn {
		local decoded_data = multipart(table.concat(body_data), req.headers["Content-Type"])
		fs.readFile(".password", fn(err, password) {
			if err {
				send_error(res, 500, "Something unexpected happened.")
				print(err)
				return
			}
			if decoded_data::get("password")?.value != password::match("[^\n]+") {
				send_error(res, 401, "Wrong password.")
				return
			}
			$code
		})
	})
}

static pprint = require("pretty-print").prettyPrint

local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"
local error_html = assert(fs.readFileSync("src/error.html"))

local fn finish_request(res, type, result, status_code) {
	if res.headersSent {
		return
	}
	if status_code {
		res.statusCode = status_code
	}
	res::setHeader("Content-Type", type)
	if result {
		res::setHeader("Content-Length", #result)
	}
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

local actions = {
	upload = fn(req, res) {
		$assert_method!("POST")
		local size = 0
		$assert_password!({
			local file = decoded_data::get("file")
			if !file || file.value == "" {
				send_error(res, 400, "No file was sent.")
				return
			}
			local r1 = math.random(0, 2^32-1)
			local r2 = ((math.random(0, 2^32-1) & 0xFFFF4FFF) | 0x4000) % 2^32
			local r3 = ((math.random(0, 2^32-1) & 0xBFFFFFFF) | 0x80000000) % 2^32
			local r4 = math.random(0, 2^32-1)
			local filename = file.headers[1]::match("filename=\"(.+)\"")
			local uuid = ("%08x%08x%08x%08x")::format(r1, r2, r3, r4)
			local truename = ("%s-%s")::format(uuid, filename)
			fs.writeFile("data/files/" .. truename, file.value, fn(err) {
				res::setHeader("Location", "/uploaded.html?file=" .. truename)
				finish_request(res, "text/plain", "Upload complete", 303)
			})
			files.add_file(
				string.pack("I4I4I4I4", r1, r2, r3, r4),
				filename,
				file.headers[2]::match("Content%-Type: (.+)"),
				decoded_data::get("ip")?.value
			)
		}, {
			size += #data
			if size >= 20000000 {
				send_error(res, 413, "File too large.")
				req::removeAllListeners()
				return
			}
		})
	}
	storage_used = fn(req, res) {
		$assert_method!("GET")
		fs.readdir("data/files", fn(err, files) {
			if err {
				send_error(res, 500, "Something unexpected happened.")
				print(err)
				return
			}
			local size = 0
			local tot_files = #files
			local fn read_file_size(err, file_info) {
				if !tot_files {
					return
				}
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
				fs.stat("data/files/" .. file, read_file_size)
			}
		})
	}
	file_list = fn(req, res) {
		$assert_method!("POST") //has to be POST since it has to have a body
		$assert_password!({
			fs.readdir("data/files", fn(err, files) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
					print(err)
					return
				}
				local list = {}
				local tot_files = 0
				local next_k = 2
				for _, file in files {
					if local filename = file::match("%d+%-([^<>]+)") {
						tot_files += 1
						if (tot_files % 3) == 1 {
							list[next_k] = "<tr class=\"file\">"
							next_k += 1
						}
						list[next_k] = ("<td class=\"file\"><a href=\"%s\" class=\"link\">%s</a></td>")
							::format(file, filename)
						if (tot_files % 3) == 0 {
							list[next_k + 1] = "</tr>"
							next_k += 2
						} else {
							next_k += 1
						}
					}
				}
				if list[next_k - 1] != "</tr>" {
					list[next_k] = "</tr>"
					next_k += 1
				}
				list[next_k] = "</table>"
				list[1] = ("<br>%d files total<table>")::format(tot_files)
				finish_request(res, "text/html", table.concat(list))
			})
		})
	}
	delete = fn(req, res) {
		$assert_method!("DELETE")
		$assert_password!({
			local filename = decoded_data::get("filename").value
			local owner = files.get_owner(filename)
			if !owner || (owner != decoded_data::get("ip")?.value) {
				send_error(res, 403, "File not uploaded by you.")
				return
			}
			fs.unlink("data/files/" .. filename, fn(err) {
				if err {
					send_error(res, 404, "File not found.")
					print(err)
					return
				}
				finish_request(res, nil, "", 204)
				files.remove_file(filename)
			})
		})
	}
}

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
	["^/+files/+([^/]+)$"] = fn(req, res, filename) {
		match req.method {
			"GET" => {
				fs.readFile("data/files/" .. filename, fn(err, file) {
					if err {
						send_error(res, 404, "File not found.")
						print(err)
						return
					}
					local info = files.get_info(filename)
					res::setHeader("Upload-Date", info[2])
					finish_request(res, info[1] || "image/png", file)
				})
			}
			"HEAD" => {
				fs.stat("data/files/" .. filename, fn(err, file_info) {
					if err {
						send_error(res, 404, "File not found.")
						print(err)
						return
					}
					local info = files.get_info(filename)
					res::setHeader("Upload-Date", info[2])
					res::setHeader("Content-Length", file_info.size)
					finish_request(res, info[1] || "image/png")
				})
			}
			default => {
				send_error(res, 400, "Wrong request method.")
			}
		}
	}
	["^/+([%l_]+)$"] = fn(req, res, action) {
		if local action = actions[action] {
			action(req, res)
		} else {
			send_error(res, 404, "Unknown action.")
		}
	}
}

http.createServer(fn(req, res) {
	local path = querystring.urldecode(http.parseUrl(req.url).pathname)
	for pattern, func of patterns {
		if local matched = path::match(pattern) {
			func(req, res, matched)
			collectgarbage()
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)
