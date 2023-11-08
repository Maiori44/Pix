set_upload_file_logic(document.getElementById("upload-form"))

const fieldset = document.getElementById("fieldset")
const container = document.getElementById("overflow-checker")

fetch("/storage_used").then(async result => {
	document.getElementById("storage-used").innerText = "Storage used: " + (result.status == 200
		? await result.text()
		: "error!")
})
