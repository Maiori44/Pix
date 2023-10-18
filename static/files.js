const password_check = document.getElementById("password-check")

password_check.addEventListener("submit", async e => {
	e.preventDefault()
	const form_data = new FormData()
	form_data.append("password", document.getElementById("password").value)
	const result = await fetch("/file_list", {
		method: "POST",
		body: form_data,
	})
	const text = await result.text()
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
	let path = "/files/"
	let old_src
	Array.from(document.getElementsByClassName("link")).forEach(link => {
		const upload_date = new Date(parseInt(link.href.match(/(\d+)-.+$/)[1]) * 1000)
		const filename = link.pathname.slice(1)
		link.addEventListener("mouseenter", () => {
			link.href = path + filename
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
	const reupload_button = document.getElementById("reupload-button")
	delete_button.og_name = delete_button.innerText
	reupload_button.og_name = reupload_button.innerText
	delete_button.classList.remove("disabled-button")
	reupload_button.classList.remove("disabled-button")
	function setup_button(button, other, cancellation, new_path, color, other_color) {
		button.addEventListener("click", () => {
			switch (button.innerText) {
				case button.og_name: {
					path = new_path
					title.innerText = `Select file to ${cancellation}...`
					button.innerText = `Cancel ${cancellation}`
					preview_text.style.color = color
					preview_text.style.opacity = "0"
					const animation = other.innerText == other.og_name
						? `fade-white-${color} 0.5s linear forwards`
						: `fade-${other_color}-${color} 0.5s linear forwards`
					console.log(animation)
					document.querySelectorAll("*").forEach(element => {
						element.style.animation = animation
					})
					other.innerText = other.og_name
					break
				}
				case `Cancel ${cancellation}`: {
					path = "/files/"
					title.innerText = "Currently uploaded files"
					button.innerText = button.og_name
					preview_text.style.color = "white"
					preview_text.style.opacity = "0"
					document.querySelectorAll("*").forEach(element => {
						element.style.animation = `fade-${color}-white 0.5s linear forwards`
					})
					break
				}
			}
		})
	}
	setup_button(delete_button, reupload_button, "delete", "/delete.html?file=", "red", "yellow")
	setup_button(reupload_button, delete_button, "reupload", "/uploaded.html?file=", "yellow", "red")
})
