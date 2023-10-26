const form = document.getElementById("replace-form")
const title = document.getElementById("title")

const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	title.classList.add("invisible")
	form.innerHTML = "<div class=\"bigger\">Replace nothingness?</div>" + 
	"That's just <a href=\"/index.html\">uploading</a> something new..."
} else {
	const img = document.getElementById("preview-file")
	img.src = "/files/" + encodeURIComponent(file)
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	document.querySelectorAll("*").forEach(element => {
		element.style.animation = `fade-yellow-white 0.5s linear forwards`
	})
	/*fetch("https://api.ipify.org").then(async result => {
		document.getElementsByName("ip")[0].value = await result.text()
		const upload_button = document.getElementsByClassName("disabled-button")[0]
		upload_button.value = "Replace file"
		upload_button.classList.remove("disabled-button")
	})*/
	form.addEventListener("submit", async e => {
		e.preventDefault()
		form.addEventListener("animationend", () => {
			form.innerHTML = "<h2>Uploading</h2>"
			let dots = 0
			window.setInterval(() => {
				dots = (dots + 1) % 4
				form.innerHTML = "<h2>Uploading" + ".".repeat(dots) + "</h2>"
			}, 500)
			form.style.animation = "fade-in 140ms linear forwards"
		}, {once: true})
		form.style.animation = "fade-out 140ms linear forwards"
		title.style.animation = "fade-out 140ms linear forwards"
		const form_data = new FormData()
		form_data.append("password", document.getElementById("password").value)
		form_data.append("file", document.getElementsByName("file")[0].files[0], file)
		form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
		const result = await fetch("/replace", {
			method: "PUT",
			body: form_data
		})
		const text = await result.text()
		if (result.status != 204) {
			document.write(text.replace("/index.html", "/files.html"))
		} else {
			window.location.href = "/uploaded.html?replaced=yes&file=" + file
		}
	})
}