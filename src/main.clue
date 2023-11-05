@version 4.0.0

@import "fragments"
@import "files"

@macro assert_method(wanted) {
	if req.method != $wanted {
		send_error(res, 400, "Wrong request method.")
		return
	}
}

@macro assert_password(code) {
	fs.readFile(".password", fn(err, password) {
		if err {
			send_error(res, 500, "Something unexpected happened.")
			print(err)
			return
		}
		if req.headers["Password"] != password::match("[^\n]+") {
			send_error(res, 401, "Wrong password.")
			return
		}
		$code
	})
}

@macro assert_owner(filename) {
	local owner = files::get_info($filename)[$OWNER]
	if !owner || (owner != req.headers["IP"]) {
		send_error(res, 403, "File not uploaded by you.")
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
		send_error(res, 400, "No file data was ever sent.")
		return
	}
	local ok, last_i = fragments.get_last_fragment_index(id)
	if !ok {
		send_error(res, 424, ("Missing fragment %d.")::format(last_i))
		return
	}
	local content_type, filename = body::match("^(.*)\n(.+)$")
	if !filename {
		send_error(res, 400, "No file name was sent.")
		return
	}
}

static pprint = require("pretty-print").prettyPrint
static error_html

static fn finish_request(res, type, result, status_code) {
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

static fn send_error(res, code, message) {
	finish_request(res, "text/html", error_html::format(code, message), code)
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

local actions = {
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
			if tot_files == 0 {
				finish_request(res, "text/plain", convert_bytes(size))
			}
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
		$assert_method!("GET")
		$assert_password!(fs.readdir("data/files", fn(err, file_list) {
			if err {
				send_error(res, 500, "Something unexpected happened.")
				print(err)
				return
			}
			local list = {}
			local tot_files = 0
			local next_k = 2
			local favourite_k = 3
			for _, file in file_list {
				if local filename = file::match("%x+%-([^<>]+)") {
					local unlisted, favourite = files::has_flags(file, $FLAG_UNLISTED, $FLAG_FAVOURITE)
					if unlisted {
						continue
					}
					tot_files += 1
					if (tot_files % 3) == 1 {
						list[next_k] = "<tr class=\"file\">"
						next_k += 1
					}
					local link = ("<a href=\"%s\" class=\"link\">%s</a>")::format(
						querystring.urlencode(file),
						filename
					)
					if favourite {
						list[next_k] = list[favourite_k]
						list[favourite_k] = ("<td class=\"file\"><span class=\"favourite\">♥</span>%s</td>")::format(link)
						favourite_k += 1
						if list[favourite_k] == "</tr>" {
							favourite_k += 2
						}
					} else {
						list[next_k] = ("<td class=\"file\">%s</td>")::format(link)
					}
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
		}))
	}
	delete = fn(req, res) {
		$assert_method!("DELETE")
		$assert_password!($read_body!({
			$assert_owner!(body)
			fs.unlink("data/files/" .. body, fn(err) {
				if err {
					send_error(res, 404, "File not found.")
					print(err)
					return
				}
				finish_request(res, nil, nil, 204)
				files::delete_file(body)
			})
		}))
	}
}

local patterns = {
	["^/+$"] = fn(_, res) {
		res::setHeader("Location", "index.html")
		finish_request(res, "text/plain", "Redirect to index.html", 303)
	}
	["^/+([%a_]+%.%a+)$"] = fn(req, res, filename) {
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
					local info = files::get_info(filename)
					res::setHeader("Upload-Date", info[$UPLOAD_DATE])
					res::setHeader("Edit-Date", info[$EDIT_DATE])
					finish_request(res, info[$CONTENT_TYPE] || "image/png", file)
				})
			}
			"HEAD" => {
				fs.stat("data/files/" .. filename, fn(err, file_info) {
					if err {
						send_error(res, 404, "File not found.")
						print(err)
						return
					}
					local info = files::get_info(filename)
					res::setHeader("Upload-Date", info[$UPLOAD_DATE])
					res::setHeader("Edit-Date", info[$EDIT_DATE])
					res::setHeader("Content-Length", file_info.size)
					finish_request(res, info[$CONTENT_TYPE] || "image/png")
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
	["^/+upload/+(%d+)/(%l+)$"] = fn(req, res, id, action) {
		$assert_method!("POST")
		$assert_password!($read_body!({
			if fragments.assert_timeout(id) {
				send_error(res, 408, "Upload timeout.")
				return
			}
			match action {
				"fragment" => {
					if local i = tonumber(req.headers["FragmentNum"]) {
						fragments.add_fragment(id, i, body)
						finish_request(res, nil, nil, 204)
					} else {
						send_error(res, 400, "Missing fragment number.")
					}
				}
				"finish" => {
					$prepare_finish!()
					local r1 = math.random(0, 2 ^ 32 - 1)
					local r2 = ((math.random(0, 2 ^ 32 - 1) & 0xFFFF4FFF) | 0x4000) % 2 ^ 32
					local r3 = ((math.random(0, 2 ^ 32 - 1) & 0xBFFFFFFF) | 0x80000000) % 2 ^ 32
					local r4 = math.random(0, 2 ^ 32 - 1)
					local uuid = ("%08x%08x%08x%08x")::format(r1, r2, r3, r4)
					local flags = tonumber(req.headers["Flags"]) || 0
					fragments.save_file(
						res,
						id,
						last_i,
						("%s-%s")::format(uuid, filename),
						files::has_flags(flags, $FLAG_TEMPORARY),
						fn(err) {
							if !err {
								files::add_file(
									string.pack("I4I4I4I4", r1, r2, r3, r4),
									filename,
									content_type,
									req.headers["IP"],
									flags
								)
							}
						}
					)
				}
				"replace" => {
					$prepare_finish!()
					$assert_owner!(filename)
					local path = "data/files/" .. filename
					fs.readFile(path, fn(_, old_file) {
						fs.unlink(path)
						fragments.save_file(res, id, last_i, filename, fn(err) {
							if err {
								fs.writeFile(path, old_file)
							} else {
								files::replace_file(filename, content_type)
							}
						})						
					})
				}
				default => {
					send_error(res, 404, "Unknown action.")
				}
			}
		}))
	}
}

http.createServer(fn(req, res) {
	local path = querystring.urldecode(http.parseUrl(req.url).pathname)
	for pattern, func of patterns {
		local m1, m2 = path::match(pattern)
		if m1 {
			func(req, res, m1, m2)
			collectgarbage()
			return
		}
	}
	send_error(res, 404, "Page not found.")
})::listen(port, ip)
