function set_upload_file_logic(form, replace) {
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const files = document.getElementById("file")
		const text = document.getElementById("title")
		const flags = document.querySelectorAll(".flag")
		let flags_value
		if (!replace) {
			flags_value = 0
			flags.forEach(td => {
				const flag = td.children[0]
				if (flag.checked)
					flags_value += parseInt(flag.value)
			})
		}
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
		let total_files = 0
		let total_size = 0
		let uploaded_files = 0
		let uploaded_size = 0
		let loaded_size = 0
		let logs = 1
		let names = []
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
		
		const workers = []
		const message_types = {
			log: msg => log(msg),
			fragment_loaded: ({size, msg}) => {
				log(msg)
				loaded_size += size
				update_percentage()
			},
			fragment_received: ({size, msg}) => {
				log(msg)
				uploaded_size += size
				update_percentage()
			},
			upload_finished: ({name, msg}) => {
				log(msg)
				uploaded_files += 1
				update_percentage()
				names.push(name)
				if (uploaded_files == total_files) {
					let args = ""
					for (const [i, name] of names.entries()) {
						args += `file${i}=${encodeURIComponent(name)}&`
					}
					window.location.href = `/uploaded.html?${args}replaced=${!!replace}&total=${names.length}`						
				}
			},
			errored: (html) => {
				document.write(replace ? html.replace("/index.html", "/files.html") : html)
				for (const worker of workers)
					worker.terminate()
			}
		}

		for (const file of files.files) {
			total_files += 1
			total_size += file.size
			const worker = new Worker("uploader.js")
			worker.postMessage({
				id: crypto.getRandomValues(new BigUint64Array(2)).join(""),
				file: file,
				password: password,
				flags: flags_value,
				replace: replace,
			})
			worker.addEventListener("message", (message) => {
				const { type, data } = message.data;
				if (message_types[type]) {
					message_types[type](data)
				} else {
					console.log(`Unhandled message type: ${type}`)
				}
			})
			workers.push(worker)
		}
	})
}
