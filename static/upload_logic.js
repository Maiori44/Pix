function set_upload_file_logic(form, replace) {
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const files = document.getElementById("file")
		const text = document.getElementById("title")
		let percentage, list
		form.addEventListener("animationend", () => {
			form.innerHTML = "<h2 id=\"uploading-text\">Uploading</h2>\n"
				+ "<span id=\"percentage\">0%</span><span id=\"event-list\"></span>"
			const uploading_text = document.getElementById("uploading-text")
			percentage = document.getElementById("percentage")
			list = document.getElementById("event-list")
			let dots = 0
			setInterval(() => {
				dots = (dots + 1) % 4
				uploading_text.innerText = "Uploading" + ".".repeat(dots)
			}, 500)
			form.style.animation = "fade-in 140ms linear forwards"
		}, { once: true })
		form.style.animation = "fade-out 140ms linear forwards"
		text.style.animation = "fade-out 140ms linear forwards"
		const headers = {
			Password: document.getElementById("password").value
		}
		const form_data = new FormData()
		form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
		let total_files = 0
		let total_size = 0
		let uploaded_files = 0
		let uploaded_size = 0
		let errored = false
		let logs = 0
		setInterval(() => {
			while (logs > 30) {
				list.children[list.children.length - 1].remove();
				logs--
			}
		}, 1000)
		let waiting_logs = ["Initiating..."]
		function log(message) {
			if (list) {
				if (waiting_logs) {
					const waited_logs = waiting_logs
					waiting_logs = null
					waited_logs.forEach(log)
				}
				let item = document.createElement("span")
				item.classList.add("log-entry")
				item.innerText = message + "\n"
				list.prepend(item)
				logs++
			} else {
				waiting_logs.push(message)
			}
		}
		async function send_fragment(reader, name, id, promise) {
			if (errored)
				return;
			const { value: value1, done: done1 } = await reader.read(new Uint8Array(65536))
			const { value: value2, done: done2 } = await reader.read(new Uint8Array(65536))
			const buffer = new Uint8Array(value1.length + value2.length)
			buffer.set(value1, 0)
			buffer.set(value2, value1.length)
			const not_done = !(done1 && done2)
			if (promise) {
				if (not_done)
					log(`${name}'s next fragment is ready, waiting response...`)
				await promise
			}
			if (not_done && !errored) {
				form_data.set("fragment", buffer)
				form_data.delete("filename")
				form_data.delete("content-type")
				log(`Sending ${name}'s next fragment...`)
				const promise = fetch(`/upload/${id}/fragment`, {
					method: "POST",
					body: form_data,
					headers
				}).then(async result => {
					if (result.status != 204) {
						if (errored)
							return
						errored = true
						const result_body = await result.text()
						document.write(
							replace
								? result_body.replace("/index.html", "/files.html")
								: result_body
						)
						return
					}
					log(`${name}'s fragment was sent!`)
					uploaded_size += buffer.length
					if (percentage) {
						const amount = Math.floor((uploaded_size / total_size) * 100000) / 1000
						percentage.innerText = total_files > 1
							? `${amount}% (${uploaded_files}/${total_files})`
							: `${amount}%`
					}
				})
				return send_fragment(reader, name, id, promise)
			}
		}
		let promises = []
		for (const file of files.files) {
			total_files += 1
			total_size += file.size
			const id = crypto.getRandomValues(new BigUint64Array(2)).join("")
			promises.push(send_fragment(
					file.stream().getReader({ mode: "byob" }),
					file.name,
					id
				).then(async () => {
				if (errored)
					return;
				form_data.delete("fragment")
				form_data.set("filename", replace ?? file.name)
				form_data.set("content-type", file.type)
				const finish_result = await fetch(`/upload/${id}/${replace ? "replace" : "finish"}`, {
					method: "POST",
					body: form_data,
					headers
				})
				const result_body = await finish_result.text()
				if (finish_result.status != 200) {
					if (errored)
						return
					errored = true
					document.write(replace ? result_body.replace("/index.html", "/files.html") : result_body)
					return
				}
				log(`${file.name} finished uploading!`)
				uploaded_files += 1
				if (percentage) {
					const amount = Math.floor((uploaded_size / total_size) * 100000) / 1000
					percentage.innerText = total_files > 1
						? `${amount}% (${uploaded_files}/${total_files})`
						: `${amount}%`
				}
				return result_body
			}))
		}
		let names = []
		for (const promise of promises) {
			names.push(await promise)
		}
		let args = ""
		for (const [i, name] of names.entries()) {
			args += `file${i}=${encodeURIComponent(name)}&`
		}
		if (!errored)
			window.location.href = `/uploaded.html?${args}replaced=${!!replace}&total=${names.length}`
	})
}