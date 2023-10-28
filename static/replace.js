const form = document.getElementById("replace-form")
const title = document.getElementById("title")

const file = new URLSearchParams(window.location.search).get("file")
if (!file) {
	title.classList.add("invisible")
	form.innerHTML = "<div class=\"bigger\">Replace nothingness?</div>" + 
	"That's just <a href=\"/index.html\">uploading</a> something new..."
} else {
	const img = document.getElementsByClassName("preview-file")[0]
	img.src = "/files/" + encodeURIComponent(file)
	img.addEventListener("error", () => {
		img.classList.add("invisible")
	})
	document.querySelectorAll("*").forEach(element => {
		element.style.animation = `fade-yellow-white 0.5s linear forwards`
	})
	set_upload_file_logic(form, file)
}