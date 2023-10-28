const params = new URLSearchParams(window.location.search)
const title = document.getElementById("file-uploaded-text")
let total_files = params.get("total")
if (!total_files) {
	title.innerText = "What are you doing here?"
} else { //<br><img id="preview-file">
	const images = document.getElementById("images")
	for (let i = 0; i < total_files; i++)
	images.innerHTML += `<img class="preview-file" src="/files/${params.get("file" + i)}">`
	/*file = "/files/" + file
	const img = document.getElementById("preview-file")
	img.src = file
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	if (params.get("replaced") == "true") {
		title.innerText = "File replaced!"
		document.getElementsByClassName("two-buttons")[1].parentElement.href = "/files.html"
	}*/
}
/*
const copy_link_button = document.getElementsByClassName("two-buttons")[0]
copy_link_button.addEventListener("click", () => {
	if (!navigator.clipboard) {
		document.getElementsByClassName("invisible")[0].remove()
		title.parentElement.innerHTML = "<span class=\"bigger\">Couldn't copy to clipboard.</span><br>"
		+ "Your browser may be restricting Pix's access to the clipboard because you're using an http "
		+ "connection instead of an https one.<br>"
		copy_link_button.innerText = "Try using https"
		copy_link_button.style.animation = "fade-white-yellow 0.5s forwards"
		copy_link_button.addEventListener("click", () => {
			window.location.href = window.location.href.replace("http://", "https://")
		})
	} else {
		navigator.clipboard.writeText(window.location.protocol + "//" + window.location.host + file)
		copy_link_button.innerText = "Link copied!"
		copy_link_button.classList.add("disabled-button")
	}
}, { once: true })
*/