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
		})
	})
})
