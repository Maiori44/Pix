const password_check = document.getElementById("password-check")

password_check.addEventListener("submit", e => {
	e.preventDefault()
	const form_data = new FormData()
	form_data.append("password", document.getElementById("password").value)
	fetch("/file_list", {
		method: "POST",
		body: form_data,
	}).then(result => {
		result.text().then(text => {
			if (result.status != 200) {
				document.write(text.replace("/index.html", "/files.html"))
				return
			}
			password_check.remove()
			document.getElementById("title").innerText = "Currently uploaded files"
			document.getElementById("files-list").insertAdjacentHTML("beforeend", text)
			const img = document.getElementById("selected-file")
			Array.from(document.getElementsByClassName("link")).forEach(link => {
				link.addEventListener("mouseenter", () => {
					img.src = link.href
					img.link = link
					img.style.opacity = "1"
					img.style.animation = "fade-in 0.2s linear"
				})
				link.addEventListener("mouseleave", () => {
					img.old_src = img.src
					img.style.opacity = "0"
					img.style.animation = "fade-out 0.2s linear"
				})
			})
			img.addEventListener("error", () => {
				img.src = img.old_src
				img.style.opacity = "0"
				img.style.animation = "fade-out 0.2s linear"
			})
		})
	})
})
