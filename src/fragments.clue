@import "files"

local timer = require("timer")
local uv = require("uv")
local fs = require("fs")

local uploading = {}

local fn write_file_fragment(res, id, i, last_i, filename, callback) {
	fs.appendFile("data/files/" .. filename, uploading[id].data[i], fn(err) {
		if err {
			send_error(res, 500, "Something unexpected happened.")
			callback(err)
			return
		}
		if i == last_i {
			uv.timer_set_repeat(uploading[id].timeout, 1)
			uv.timer_again(uploading[id].timeout)
			finish_request(res, "text/plain", filename, 200)
			callback()
		} else {
			write_file_fragment(res, id, i + 1, last_i, filename, callback)
		}
	})
}

return {
	assert_timeout = fn(id) {
		return uploading[id] == false
	}
	add_fragment = fn(id, i, fragment) {
		if !uploading[id] {
			uploading[id] = {
				size = 0
				data = {}
				timeout = timer.setInterval(120000, fn {
					timer.clearTimer(uploading[id].timeout)
					uploading[id] = false
					timer.setTimeout(300000, fn {
						uploading[id] = nil
					})
					collectgarbage()
				})
			}
		} else {
			uv.timer_again(uploading[id].timeout)
		}
		uploading[id].data[i] = fragment
		uploading[id].size += #fragment
		return uploading[id].size < 4000000000
	}
	assert_exist = fn(id) {
		return uploading[id] != nil
	}
	get_last_fragment_index = fn(id) {
		local finished_file = uploading[id]
		local merged_size = 0
		local last_i = 0
		loop {
			last_i += 1
			if local fragment = finished_file.data[last_i] {
				merged_size += #fragment
			} else {
				return false, last_i
			}
		} until merged_size == finished_file.size
		return true, last_i
	}
	save_file = fn(res, id, last_i, filename, temporary, callback) {
		if temporary {
			fs.symlink("/tmp/" .. filename, "data/files/" .. filename, fn(err) {
				if err {
					send_error(res, 500, "Something unexpected happened.")
					print(err)
					callback(err)
					return
				}
				write_file_fragment(res, id, 1, last_i, filename, callback)
				timer.setTimeout(3600000, fn {
					files::delete_file(filename)
					fs.unlink("data/files/" .. filename)
					fs.unlink("/tmp/" .. filename)
				})
			})
		} else {
			write_file_fragment(res, id, 1, last_i, filename, callback)
		}
	}
}