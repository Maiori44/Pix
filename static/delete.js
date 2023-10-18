const form = document.getElementById("delete-file-form")

const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	form.innerHTML = "You can't delete nothingness."
} else {
	const img = document.getElementById("preview-file")
	img.src = "/files/" + file
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	document.querySelectorAll("*").forEach(element => {
		element.style.color = "red"
		element.style.borderColor = "red"
	})
	form.addEventListener("submit", e => {
		e.preventDefault()
		const form_data = new FormData()
		form_data.append("password", document.getElementById("password").value)
		fetch("/delete", {
			method: "DELETE",
			body: form_data,
		}).then(result => {
			result.text().then(text => {
				if (result.status != 200) {
					document.write(text.replace("/index.html", "/files.html"))
				} else {
					console.log(img.style.animation)
					document.getElementById("warning-title").innerText = "File deleted."
					document.getElementById("warning-info").classList.add("invisible")
					document.getElementById("delete-button").remove()
					const password_table = document.getElementById("password-table")
					password_table.classList.add("disabled-button")
					password_table.style.opacity = "0"
				}
				document.querySelectorAll("*").forEach(element => {
					element.style.animation = "fade-red-white 0.5s linear forwards"
				})
				img.style.animation = "fade-out 1s linear forwards"
			})
		})
	})
}
