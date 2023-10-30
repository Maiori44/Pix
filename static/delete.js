const form = document.getElementById("delete-file-form")

const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	form.innerHTML = "You can't delete nothingness."
} else {
	const img = document.getElementsByClassName("preview-file")[0]
	img.src = "/files/" + encodeURIComponent(file)
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	document.querySelectorAll("*").forEach(element => {
		element.style.color = "red"
		element.style.borderColor = "red"
	})
	form.addEventListener("submit", async e => {
		e.preventDefault()
		const form_data = new FormData()
		form_data.append("filename", file)
		form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
		const result = await fetch("/delete", {
			method: "DELETE",
			body: form_data,
			headers: {
				Password: document.getElementById("password").value
			}
		})
		const text = await result.text()
		if (result.status != 204) {
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
		if (!img.classList.contains("invisible")) {
			img.style.animation = "fade-out 1s linear forwards"
		}
	})
}
