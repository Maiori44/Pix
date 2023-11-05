function set_upload_file_logic(form, replace) {
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const files = document.getElementById("file")
		const text = document.getElementById("title")
		const flags = document.querySelectorAll(".flag")
		let percentage, list
		form.addEventListener("animationend", () => {
			form.innerHTML = "<h2 id=\"uploading-text\">Uploading</h2>\n"
				+ "<span id=\"percentage\">0%</span>"
				+ "<span id=\"event-list\"><span>Initializing...</span></span>"
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
		const password = document.getElementById("password").value
		const ip = await (await fetch("https://api.ipify.org")).text()
		let total_files = 0
		let total_size = 0
		let uploaded_files = 0
		let uploaded_size = 0
		let loaded_size = 0
		let errored = false
		let logs = 1
		setInterval(() => {
			while (logs > 30) {
				list.children[list.children.length - 1].remove();
				logs--
			}
		}, 1000)
		let waiting_logs = []

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

		function update_percentage() {
			if (percentage) {
				const amount = Math.floor((loaded_size / total_size) * 100000) / 1000
				let main_text = total_size >= 65536
					? `${amount}% (Received: ${Math.floor((uploaded_size / total_size) * 100000) / 1000}%)`
					: `${amount}%`
				percentage.innerText = total_files > 1
					? `${main_text} (${uploaded_files}/${total_files})`
					: main_text
			}
		}

		let names = []
		let requests = 0

		async function send_file(file) {
			total_files += 1
			total_size += file.size
			const reader = file.stream().getReader({ mode: "byob" })
			const id = crypto.getRandomValues(new BigUint64Array(2)).join("")
			const fragments = []
			let i = 1
			while (!errored) {
				const { value, done } = await reader.read(new Uint8Array(65536))
				loaded_size += value.length
				update_percentage()
				if (requests >= 1000)
					while (requests > 500)
						await fragments.pop()
				const current_i = i
				log(`Sending ${file.name}'s fragment n°${i}...`)
				requests++
				fragments.push(fetch(`/upload/${id}/fragment`, {
					method: "POST",
					body: value,
					headers: {
						Password: password,
						FragmentNum: i++,
					}
				}).then(async result => {
					requests--
					if (result.status != 204) {
						if (errored) return
						errored = true
						const result_body = await result.text()
						document.write(
							replace
								? result_body.replace("/index.html", "/files.html")
								: result_body
						)
						return
					}
					log(`${file.name}'s fragment n°${current_i} was received!`)
					uploaded_size += value.length
					update_percentage()
				}, reason => {
					errored = true
					log(`${filename}: ${reason}`)
				}))
				if (done) break
			}
			log(`All of ${file.name}'s fragments were sent! Waiting for receival...`)
			for (const promise of fragments) {
				if (errored) return
				await promise
			}
			log(`All of ${file.name}'s fragments were received! Finishing upload...`)
			let flags_value
			if (!replace) {
				flags_value = 0
				flags.forEach(td => {
					const flag = td.children[0]
					if (flag.checked)
						flags_value += parseInt(flag.value)
				})
			}
			const finish_result = await fetch(`/upload/${id}/${replace ? "replace" : "finish"}`, {
				method: "POST",
				body: `${file.type}\n${replace ?? file.name}`,
				headers: {
					Password: password,
					IP: ip,
					Flags: flags_value,
				}
			})
			const result_body = await finish_result.text()
			if (finish_result.status != 200) {
				if (errored) return
				errored = true
				document.write(replace ? result_body.replace("/index.html", "/files.html") : result_body)
				return
			}
			log(`${file.name} finished uploading!`)
			uploaded_files += 1
			update_percentage()
			names.push(result_body)
			if (uploaded_files == total_files) {
				let args = ""
				for (const [i, name] of names.entries()) {
					args += `file${i}=${encodeURIComponent(name)}&`
				}
				if (!errored)
					window.location.href = `/uploaded.html?${args}replaced=${!!replace}&total=${names.length}`
			}
		}
		for (const file of files.files) send_file(file)
	})
}
