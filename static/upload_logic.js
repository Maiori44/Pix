function set_upload_file_logic(form, replace) {
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const files = document.getElementById("file")
		const text = document.getElementById("title")
		let dots_text = "Uploading"
		let dots_interval, percentage
		form.addEventListener("animationend", () => {
			form.innerHTML = "<h2 id=\"uploading-text\">Uploading</h2>\n<span id=\"percentage\">0%</span>"
			const uploading_text = document.getElementById("uploading-text")
			percentage = document.getElementById("percentage")
			let dots = 0
			dots_interval = window.setInterval(() => {
				dots = (dots + 1) % 4
				uploading_text.innerText = dots_text + ".".repeat(dots)
			}, 500)
			form.style.animation = "fade-in 140ms linear forwards"
		}, { once: true })
		form.style.animation = "fade-out 140ms linear forwards"
		text.style.animation = "fade-out 140ms linear forwards"
		const base_id = (Date.now() * 100 + Math.floor(Math.random() * 1000)) * Math.pow(10, files.files.length.toString().length)
		const form_data = new FormData()
		form_data.append("password", document.getElementById("password").value)
		form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
		let total_files = 0
		let total_size = 0
		let uploaded_files = 0
		let uploaded_size = 0
		let errored = false
		async function send_fragment(reader, id, promise) {
			if (errored)
				return;
			const { value: value1, done: done1 } = await reader.read(new Uint8Array(65536))
			const { value: value2, done: done2 } = await reader.read(new Uint8Array(65536))
			const buffer = new Uint8Array(value1.length + value2.length)
			buffer.set(value1, 0)
			buffer.set(value2, value1.length)
			if (promise) {
				await promise
			}
			if (!(done1 && done2) && !errored) {
				form_data.set("fragment", buffer)
				form_data.delete("filename")
				form_data.delete("content-type")
				const promise = fetch(`/upload/${id}/fragment`, {
					method: "POST",
					body: form_data
				}).then(async result => {
					if (result.status != 204) {
						errored = true
						const result_body = await result.text()
						document.write(
							replace
								? result_body.replace("/index.html", "/files.html")
								: result_body
						)
						return
					}
					uploaded_size += buffer.length
					if (percentage) {
						const amount = Math.floor((uploaded_size / total_size) * 100000) / 1000
						percentage.innerText = total_files > 1
							? `${amount}% (${uploaded_files}/${total_files})`
							: `${amount}%`
					}
				})
				return send_fragment(reader, id, promise)
			}
		}
		let promises = []
		let i = 0
		for (const file of files.files) {
			total_files += 1
			total_size += file.size
			const id = base_id + i++
			promises.push(send_fragment(file.stream().getReader({ mode: "byob" }), id).then(async () => {
				if (errored)
					return;
				form_data.delete("fragment")
				form_data.set("filename", replace ?? file.name)
				form_data.set("content-type", file.type)
				const finish_result = await fetch(`/upload/${id}/${replace ? "replace" : "finish"}`, {
					method: "POST",
					body: form_data
				})
				const result_body = await finish_result.text()
				if (finish_result.status != 200) {
					errored = true
					document.write(replace ? result_body.replace("/index.html", "/files.html") : result_body)
					return
				}
				uploaded_files += 1
				return result_body
			}))
		}
		let names = []
		for (const promise of promises) {
			names.push(await promise)
		}
		let args = ""
		for (const [i, name] of names.entries()) {
			args += `file${i}=${encodeURIComponent((name))}&`
		}
		window.location.href = `/uploaded.html?${args}replaced=${!!replace}&total=${names.length}`
	})
}