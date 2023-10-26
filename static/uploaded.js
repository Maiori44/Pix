const params = new URLSearchParams(window.location.search)
const title = document.getElementById("file-uploaded-text")
let file = params.get("file")
if (!file) {
	title.innerText = "What are you doing here?"
} else {
	file = "/files/" + encodeURIComponent(file)
	const img = document.getElementById("preview-file")
	img.src = file
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	if (params.get("replaced") == "true") {
		title.innerText = "File replaced!"
		document.getElementsByClassName("two-buttons")[1].parentElement.href = "/files.html"
	}
}

const copy_link_button = document.getElementsByClassName("two-buttons")[0]
copy_link_button.addEventListener("click", () => {
	navigator.clipboard.writeText(window.location.protocol + "//" + window.location.host + file)
	copy_link_button.innerText = "Link copied!"
	copy_link_button.classList.add("disabled-button")
})
