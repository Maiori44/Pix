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
			const title = document.getElementById("title")
			title.innerText = "Currently uploaded files"
			document.getElementById("file-list").insertAdjacentHTML("beforeend", text)
			const img = document.getElementById("preview-file")
			const preview_text = document.getElementById("preview-text")
			img.style.opacity = "0"
			let target_opacity = 0
			let next_target_opacity = 0
			let old_src
			Array.from(document.getElementsByClassName("link")).forEach(link => {
				const upload_date = new Date(parseInt(link.href.match(/(\d+)-.+$/)[1]) * 1000)
				link.addEventListener("mouseenter", () => {
					preview_text.innerText = "Upload date: " + upload_date.toLocaleString()
					preview_text.style.animation = "fade-in 140ms linear forwards"
					old_src = img.src
					img.src = link.href
					next_target_opacity = 1
				})
				link.addEventListener("mouseleave", () => {
					preview_text.style.animation = "fade-out 140ms linear forwards"
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
			const delete_button = document.getElementById("delete-button")
			//delete_button.classList.remove("disabled-button")
			delete_button.addEventListener("click", () => {
				title.innerText = "Select file to delete.\nWell actually this feature is unfinished..."
				preview_text.style.color = "red"
				document.querySelectorAll("*").forEach(element => {
					element.style.animation = "fade-red 0.5s linear forwards"
				})
			})
		})
	})
})
