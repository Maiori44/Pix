@import "files"

@define TEMPORARY_FILE_TIMEOUT 3600000

local uv = require("uv")
local fs = require("fs")

local uploading = {}

local fn write_file_fragment(req, res, id, i, last_i, filename, callback) {
	fs.appendFile("data/files/" .. filename, uploading[id].data[i], fn(err) {
		$assert!(500, "Something unexpected happened.", callback(err))
		if i == last_i {
			uv.timer_set_repeat(uploading[id].timeout, 1)
			uv.timer_again(uploading[id].timeout)
			finish_request(req, res, "text/plain", filename, 201)
			callback()
		} else {
			write_file_fragment(req, res, id, i + 1, last_i, filename, callback)
		}
	})
}

local fn delete_temporary_file(filename) {
	files.delete_file(filename)
	fs.unlink("data/files/" .. filename)
	fs.unlink("/tmp/" .. filename)
}

for _, data in files.get_flagged_files($FLAG_TEMPORARY) {
	local uuid, filename, upload_date = unpack(data)
	local r1, r2, r3, r4 = ("I4I4I4I4")::unpack(uuid)
	timer.setTimeout(
		math.max(tonumber((upload_date * 1000 + $TEMPORARY_FILE_TIMEOUT) - os.time() * 1000), 0),
		delete_temporary_file,
		("%08x%08x%08x%08x-%s")::format(r1, r2, r3, r4, filename)
	)
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
	save_file = fn(req, res, id, last_i, filename, symlink, callback) {
		if symlink {
			fs.symlink("/tmp/" .. filename, "data/files/" .. filename, fn(err) {
				$assert!(500, "Something unexpected happened.", print(err), callback(err))
				write_file_fragment(req, res, id, 1, last_i, filename, callback)
				timer.setTimeout($TEMPORARY_FILE_TIMEOUT, delete_temporary_file, filename)
			})
		} else {
			write_file_fragment(req, res, id, 1, last_i, filename, callback)
		}
	}
}
