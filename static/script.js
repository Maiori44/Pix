const form = document.getElementById("upload-form")

form.addEventListener("submit", _ => {
	const text = document.getElementById("upload-disappear")
	form.style.opacity = 1
	text.style.opacity = 1
	const disappear_interval = window.setInterval(() => {
		form.style.opacity = parseFloat(form.style.opacity) - 0.05
		text.style.opacity = parseFloat(text.style.opacity) - 0.05
		if (parseFloat(form.style.opacity) <= 0) {
			form.innerHTML = "<h2>Uploading</h2>"
			let dots = 0
			window.setInterval(() => {
				dots = (dots + 1) % 4
				form.innerHTML = "<h2>Uploading" + ".".repeat(dots) + "</h2>"
			}, 500)
			const appear_interval = window.setInterval(() => {
				form.style.opacity = parseFloat(form.style.opacity) + 0.05
				if (parseFloat(form.style.opacity) >= 1) {
					window.clearInterval(appear_interval)
				}
			}, 7)
			window.clearInterval(disappear_interval)
		}
	}, 7)
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

fetch("/storage_used").then(result => {
	result.text().then(text => {
		document.getElementById("storage-used").innerText = "Storage used: " + text
	})
})

const password = document.getElementsByName("password")[0]
const file = document.getElementsByName("file")[0]

document.getElementById("files-button").addEventListener("focusin", () => {
	password.setAttribute("required", "")
	file.removeAttribute("required")
})

document.getElementById("upload-button").addEventListener("focusin", () => {
	password.setAttribute("required", "")
	file.setAttribute("required", "")
})