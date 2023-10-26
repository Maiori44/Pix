const form = document.getElementById("upload-form")

/*fetch("https://api.ipify.org").then(async result => {
	document.getElementsByName("ip")[0].value = await result.text()
	const upload_button = document.getElementsByClassName("disabled-button")[0]
	upload_button.value = "Upload file"
	upload_button.classList.remove("disabled-button")
})*/

form.addEventListener("submit", async e => {
	e.preventDefault()
	const id = Date.now() * 100 + Math.floor(Math.random() * 1000)
	const form_data = new FormData()
	const file = document.getElementById("file").files[0]
	const text = document.getElementById("upload-disappear")
	let dots_interval, percentage
	form.addEventListener("animationend", () => {
		form.innerHTML = "<h2 id=\"uploading-text\">Uploading</h2>\n<span id=\"percentage\">0%</span>"
		const uploading_text = document.getElementById("uploading-text")
		percentage = document.getElementById("percentage")
		let dots = 0
		dots_interval = window.setInterval(() => {
			dots = (dots + 1) % 4
			uploading_text.innerText = "Uploading" + ".".repeat(dots)
		}, 500)
		form.style.animation = "fade-in 140ms linear forwards"
	}, {once: true})
	form.style.animation = "fade-out 140ms linear forwards"
	text.style.animation = "fade-out 140ms linear forwards"
	form_data.append("password", document.getElementById("password").value)
	form_data.append("ip", await (await fetch("https://api.ipify.org")).text())
	let uploaded_size = 0
	for await (const chunk of file.stream()) {
		form_data.set("fragment", chunk)
		const result = await fetch(`/upload/${id}/fragment`, {
			method: "POST",
			body: form_data
		})
		if (result.status != 204) {
			document.clearInterval(dots_interval)
			document.write(await result.text())
			break
		}
		uploaded_size += chunk.length
		if (percentage) {
			percentage.innerText = `${Math.floor((uploaded_size / file.size) * 100000) / 1000}%`
		}
	}
	form.innerHTML = "<h2>Done!</h2>"
})

const fieldset = document.getElementById("fieldset")
const container = document.getElementById("overflow-checker")

fieldset.style.height = "173px"

let prev_height = container.offsetHeight
let momy = 0

window.setInterval(() => {
	if (prev_height != container.offsetHeight) {
		momy = container.offsetHeight - prev_height
	}
	if (momy) {
		const amount = momy / Math.abs(momy)
		const new_height = parseFloat(fieldset.style.height) + amount
		fieldset.style.height = Math.max(new_height, 173).toString() + "px"
		momy -= amount
	}
	prev_height = container.offsetHeight
}, 7)

fetch("/storage_used").then(async result => {
	document.getElementById("storage-used").innerText = "Storage used: " + (result.status == 200
		? await result.text()
		: "error!")
})
