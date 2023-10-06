const form = document.getElementById("upload-form")
form.addEventListener("submit", e => {
	const text = document.getElementById("upload-disappear")
	form.style.opacity = 1
	text.style.opacity = 1
	const disappear_interval = window.setInterval(() => {
		form.style.opacity = parseFloat(form.style.opacity) - 0.05
		text.style.opacity = parseFloat(text.style.opacity) - 0.05
		if (parseFloat(form.style.opacity) <= 0) {
			form.innerHTML = "<h2>Loading...</h2>"
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