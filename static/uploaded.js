const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	document.getElementById("file-uploaded-text").innerText = "What are you doing here?"
} else {
	const img = document.getElementById("uploaded-file")
	img.src = "/files/" + file
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
}

const copy_link_button = document.getElementsByClassName("uploaded-button")[0]
copy_link_button.addEventListener("click", () => {
	navigator.clipboard.writeText(window.location.protocol + "//" + window.location.host + "/files/" + file)
	copy_link_button.innerText = "Link copied!"
	copy_link_button.classList.add("disabled-button")
})