@version 4.0.0

@import "fragments"
@import "files"

@macro assert_method(wanted) {
	if req.method != $wanted {
		res::setHeader("Allow", $wanted)
		send_error(req, res, 405, "Wrong request method.")
		return
	}
}

@macro assert_password(code) {
	fs.readFile(".passwordeee", fn(err, password) {
		$assert!(500, "Something unexpected happened.", print(err))
		if req.headers["Password"] != password::match("[^\n]+") {
			send_error(req, res, 401, "Wrong password.")
			return
		}
		$code
	})
}

@macro assert_owner(filename) {
	local owner = files.get_info($filename)[$OWNER]
	if !owner || (owner != req.ip) {
		send_error(req, res, 403, "File not uploaded by you.")
		return
	}
}

@macro assert(code, message, ...) {
	if err {
		send_error(req, res, $code, $message)
		${$vararg}
		return
	}
}

@macro read_body(code) {
	local body_data = {}
	req::on("data", fn(data) {
		table.insert(body_data, data)
	})
	req::on("end", fn {
		local body = table.concat(body_data)
		$code
	})
}

@macro prepare_finish() {
	if !fragments.assert_exist(id) {
		send_error(req, res, 400, "No file data was ever sent.")
		return
	}
	local ok, last_i = fragments.get_last_fragment_index(id)
	if !ok {
		send_error(req, res, 424, ("Missing fragment %d.")::format(last_i))
		return
	}
	local content_type, filename = body::match("^(.*)\n(.+)$")
	if !filename {
		send_error(req, res, 400, "No file name was sent.")
		return
	}
}

@macro finish_file_request(file) {
	local info = files.get_info(filename)
	res::setHeader("Upload-Date", tonumber(info[$UPLOAD_DATE] * 1000))
	res::setHeader("Edit-Date", tonumber(info[$EDIT_DATE] && info[$EDIT_DATE] * 1000))
	res::setHeader("Cache-Control", "max-age=604800")
	res::setHeader("Access-Control-Allow-Origin", "*")
	if info[$FLAGS] && files.has_flags(info[$FLAGS], $FLAG_TEMPORARY) {
		res::setHeader("Delete-Date", tonumber(info[$UPLOAD_DATE] * 1000 + $TEMPORARY_FILE_TIMEOUT))
	}
	finish_request(req, res, info[$CONTENT_TYPE] || "image/png", $file)
}

static pprint = require("pretty-print").prettyPrint
static timer = require("timer")
static error_html

static fn log_request(req, res) {
	print(("\27[1;34m%s\27[1;36m %s\27[0m from \27[1;33m%s\27[0m -> %s%d\27[0m")::format(
		req.method,
		req.url,
		req.ip,
		match math.floor(res.statusCode / 100) {
			2 => "\27[0;32m",
			3 => "\27[0;90m",
			4 => "\27[0;35m",
			5 => "\27[0;95m",
			default => "",
		},
		res.statusCode
	))
}

static fn finish_request(req, res, type, result, status_code) {
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
	timer.setImmediate(log_request, req, res)
}

static fn send_error(req, res, code, message) {
	finish_request(req, res, "text/html", error_html::format(code, message), code)
}

local childprocess = require('childprocess')
local querystring = require("querystring")
local http = require("http")
local fs = require("fs")

local port, ip = args[2] || 41023, args[3] || "0.0.0.0"
error_html = assert(fs.readFileSync("src/error.html"))

local fn convert_bytes(bytes) {
	local sizes = {"B", "KB", "MB", "GB"}
    local i = 1
    while bytes >= 1000 && i < #sizes {
        bytes = bytes / 1000
        i += 1
    }
    return ("%.1f%s")::format(bytes, sizes[i])
}

local cache = {
	@ifdef NOCACHE {
		meta newindex = fn(t, k, v) {
			print(("File \"%s\" was not cached since NOCACHE was enabled.")::format(k))
		}
	}
}

local patterns = {
	["^/+$"] = fn(req, res) {
		res::setHeader("Location", "index.html")
		finish_request(req, res, "text/plain", "Redirect to /index.html\n", 303)
	}
	["^/+([%a_]+%.%a+)$"] = fn(req, res, filename) {
		$assert_method!("GET")
		if local cached = cache[filename] {
			res::setHeader("Cache-Control", "max-age=7200")
			finish_request(req, res, cached.type, cached.file)
		} else {
			fs.readFile("static/" .. filename, fn(err, file) {
				$assert!(404, "File not found.", print(err))
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
				res::setHeader("Cache-Control", "max-age=7200")
				finish_request(req, res, type, file)
			})
		}
	}
	["^/+files/+([^/]+)$"] = fn(req, res, filename) {
		match req.method {
			"GET" => {
				fs.readFile("data/files/" .. filename, fn(err, file) {
					$assert!(404, "File not found.", print(err))
					$finish_file_request!(file)
				})
			}
			"HEAD" => {
				fs.stat("data/files/" .. filename, fn(err, file_info) {
					$assert!(404, "File not found.", print(err))
					res::setHeader("Content-Length", file_info.size)
					$finish_file_request!(nil)
				})
			}
			"DELETE" => {
				$assert_password!({
					$assert_owner!(filename)
					fs.unlink("data/files/" .. filename, fn(err) {
						$assert!(404, "File not found.", print(err))
						finish_request(req, res, nil, nil, 204)
						files.delete_file(filename)
					})
				})
			}
			default => {
				res::setHeader("Allow", "GET, HEAD, DELETE")
				send_error(req, res, 405, "Wrong request method.")
			}
		}
	}
	["^/+files/*$"] = fn(req, res) {
		$assert_method!("GET")
		$assert_password!(fs.readdir("data/files", fn(err, file_list) {
			$assert!(500, "Something unexpected happened.", print(err))
			local favourites, others = {}, {}
			for _, file in file_list {
				local unlisted, favourite = files.has_flags(file, $FLAG_UNLISTED, $FLAG_FAVOURITE)
				if !unlisted {
					if local filename = file::match("%x+%-([^<>]+)") {
						table.insert(
							favourite ? favourites : others,
							("[\"%s\", \"%s\"]")::format(querystring.urlencode(file), filename)
						)
					}
				}
			}
			finish_request(
				req,
				res,
				"application/json",
				("{\"favourites\":[%s],\"others\":[%s]}")::format(
					table.concat(favourites, ","),
					table.concat(others, ",")
				)
			)
		}))
	}
	["^/+storage_used$"] = fn(req, res) {
		$assert_method!("GET")
		fs.readdir("data/files", fn(err, files) {
			$assert!(500, "Something unexpected happened.", print(err))
			local size = 0
			local tot_files = #files
			if tot_files == 0 {
				finish_request(req, res, "text/plain", convert_bytes(size))
			}
			local fn read_file_size(err, file_info) {
				if !tot_files {
					return
				}
				$assert!(500, "Something unexpected happened.", print(err), tot_files = nil)
				size += file_info.size
				tot_files -= 1
				if tot_files == 0 {
					finish_request(req, res, "text/plain", convert_bytes(size))
				}
			}
			for k, file in files {
				fs.stat("data/files/" .. file, read_file_size)
			}
		})
	}
	["^/+upload/+(%d+)/+(%l+)$"] = fn(req, res, id, action) {
		$assert_method!("POST")
		$assert_password!($read_body!({
			if fragments.assert_timeout(id) {
				send_error(req, res, 410, "Upload timeout.")
				return
			}
			match action {
				"fragment" => {
					if local i = tonumber(req.headers["FragmentNum"]) {
						fragments.add_fragment(id, i, body)
						finish_request(req, res, nil, nil, 204)
					} else {
						send_error(req, res, 400, "Missing fragment number.")
					}
				}
				"finish" => {
					$prepare_finish!()
					local r1 = math.random(0, 2 ^ 32 - 1)
					local r2 = ((math.random(0, 2 ^ 32 - 1) & 0xFFFF4FFF) | 0x4000) % 2 ^ 32
					local r3 = ((math.random(0, 2 ^ 32 - 1) & 0xBFFFFFFF) | 0x80000000) % 2 ^ 32
					local r4 = math.random(0, 2 ^ 32 - 1)
					local flags = tonumber(req.headers["Flags"]) || 0
					fragments.save_file(
						req,
						res,
						id,
						last_i,
						("%08x%08x%08x%08x-%s")::format(r1, r2, r3, r4, filename),
						files.has_flags(flags, $FLAG_TEMPORARY),
						fn(err) {
							if !err {
								files.add_file(
									string.pack("I4I4I4I4", r1, r2, r3, r4),
									filename,
									content_type,
									req.ip,
									flags
								)
							}
						}
					)
				}
				"replace" => {
					$prepare_finish!()
					$assert_owner!(filename)
					local rawpath = "data/files/" .. filename
					fs.readlink(rawpath, fn(_, path = rawpath) {
						fs.readFile(path, fn(_, old_file) {
							fs.unlink(path, fn {
								fragments.save_file(
									req,
									res,
									id,
									last_i,
									filename,
									false,
									fn(err) {
										if err {
											fs.writeFile(path, old_file)
										} else {
											files.replace_file(filename, content_type)
										}
									}
								)	
							})
						})
					})
				}
				default => {
					send_error(req, res, 404, "Unknown action.")
				}
			}
		}))
	}
}

http.createServer(fn(req, res) {
	req.ip = req.headers["X-Forwarded-For"]?::match("^[^,]*") || req.socket::address().ip
	local path = querystring.urldecode(req.url::match("^(.-)%?.+$") || req.url)
	for pattern, func of patterns {
		local m1, m2 = path::match(pattern)
		if m1 {
			func(req, res, m1, m2)
			collectgarbage()
			return
		}
	}
	send_error(req, res, 404, "Page not found.")
})::listen(port, ip)
