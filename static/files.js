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
			document.getElementById("file-list").insertAdjacentHTML("beforeend", text)
			const img = document.getElementById("selected-file")
			img.style.opacity = "0"
			let target_opacity = 0
			let next_target_opacity = 0
			let old_src
			Array.from(document.getElementsByClassName("link")).forEach(link => {
				link.addEventListener("mouseenter", () => {
					old_src = img.src
					img.src = link.href
					next_target_opacity = 1
				})
				link.addEventListener("mouseleave", () => {
					next_target_opacity = 0
					target_opacity = 0
				})
			})
			img.addEventListener("error", () => {
				img.src = old_src
				target_opacity = 0
				next_target_opacity = 0
			})
			img.addEventListener("load", () => {
				target_opacity = next_target_opacity
			})
			window.setInterval(() => {
				const opacity = parseFloat(img.style.opacity)
				if (opacity < target_opacity) {
					img.style.opacity = opacity + 0.05
				} else if (opacity > target_opacity) {
					img.style.opacity = opacity - 0.05					
				}
			}, 7)
		})
	})
})
