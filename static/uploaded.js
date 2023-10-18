const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	document.getElementById("file-uploaded-text").innerText = "What are you doing here?"
} else {
	const img = document.getElementById("preview-file")
	img.src = "/files/" + file
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
}

const copy_link_button = document.getElementsByClassName("two-buttons")[0]
copy_link_button.addEventListener("click", () => {
	const url = window.location.protocol + "//" + window.location.host + "/files/" + encodeURIComponent(file)
	navigator.clipboard.writeText(url)
	copy_link_button.innerText = "Link copied!"
	copy_link_button.classList.add("disabled-button")
})
