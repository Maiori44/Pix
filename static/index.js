const form = document.getElementById("upload-form")

form.addEventListener("submit", _ => {
	const text = document.getElementById("upload-disappear")
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
	text.style.animation = "fade-out 140ms linear forwards"
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
		document.getElementById("storage-used").innerText = "Storage used: " + (result.status == 200
			? text
			: "error!")
	})
})
