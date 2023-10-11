const file = new URLSearchParams(window.location.search).get("file")
console.log(file)
if (!file) {
	document.getElementById("file-uploaded-text").innerText = "What are you doing here?"
} else {
	document.getElementById("uploaded-file").src = "/files/" + file
}
