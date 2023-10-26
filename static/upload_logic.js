function set_upload_file_logic(form, replace) {
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const file = document.getElementById("file").files[0]
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
		}, {once: true})
		form.style.animation = "fade-out 140ms linear forwards"
		text.style.animation = "fade-out 140ms linear forwards"
		const id = Date.now() * 100 + Math.floor(Math.random() * 1000)
		const form_data = new FormData()
		form_data.append("password", document.getElementById("password").value)
		form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
		let uploaded_size = 0
		for await (const chunk of file.stream()) {
			form_data.set("fragment", chunk)
			const fragment_result = await fetch(`/upload/${id}/fragment`, {
				method: "POST",
				body: form_data
			})
			if (fragment_result.status != 204) {
				document.clearInterval(dots_interval)
				const result_body = await fragment_result.text()
				document.write(replace ? result_body.replace("/index.html", "/files.html") : result_body)
				return
			}
			uploaded_size += chunk.length
			if (percentage) {
				percentage.innerText = `${Math.floor((uploaded_size / file.size) * 100000) / 1000}%`
			}
		}
		dots_text = "Finishing"
		form_data.delete("fragment")
		form_data.append("filename", file.name)
		form_data.append("content-type", file.type)
		const finish_result = await fetch(`/upload/${id}/${replace ? "replace" : "finish"}`, {
			method: "POST",
			body: form_data
		})
		clearInterval(dots_interval)
		const result_body = await finish_result.text()
		if (finish_result.status != 200) {
			document.write(replace ? result_body.replace("/index.html", "/files.html") : result_body)
			return
		}
		window.location.href = `/uploaded.html?file=${result_body}&replaced=${replace}`
	})
}