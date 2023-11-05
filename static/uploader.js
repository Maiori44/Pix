onmessage = async (message) => {
	const { id, file, password, flags, ip, replace } = message.data
	const reader = file.stream().getReader({ mode: "byob" })
	const fragments = []
	let finished = false
	let i = 1
	do {
		const { value, done } = await reader.read(new Uint8Array(65536))
		postMessage({
			type: "fragment_loaded",
			data: {
				size: value.length,
				msg: `Sending ${file.name}'s fragment n°${i}...`
			}
		})
		if (fragments.length >= 500)
			while (fragments[0])
				await fragments.pop()
		const current_i = i
		fragments.push(fetch(`/upload/${id}/fragment`, {
			method: "POST",
			body: value,
			headers: {
				Password: password,
				FragmentNum: i++,
			}
		}).then(async result => {
			if (result.status != 204) {
				postMessage({
					type: "errored",
					data: await result.text()
				})
				return
			}
			postMessage({
				type: "fragment_received",
				data: {
					size: value.length,
					msg: `${file.name}'s fragment n°${current_i} was received!`
				}
			})
		}))
		finished = done
	} while (!finished)
	postMessage({
		type: "log",
		data: `All of ${file.name}'s fragments were sent! Waiting for receival...`
	})
	for (const promise of fragments) {
		await promise
	}
	postMessage({
		type: "log",
		data: `All of ${file.name}'s fragments were received! Finishing upload...`
	})
	const finish_result = await fetch(`/upload/${id}/${replace ? "replace" : "finish"}`, {
		method: "POST",
		body: `${file.type}\n${replace ?? file.name}`,
		headers: {
			Password: password,
			IP: ip,
			Flags: flags,
		}
	})
	const result_body = await finish_result.text()
	if (finish_result.status != 200) {
		postMessage({
			type: "errored",
			data: result_body 
		})
		return
	}
	postMessage({
		type: "upload_finished",
		data: {
			name: result_body,
			msg: `${file.name} finished uploading!`
		}
	})
}
