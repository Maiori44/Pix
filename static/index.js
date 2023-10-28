set_upload_file_logic(document.getElementById("upload-form"))

const fieldset = document.getElementById("fieldset")
const container = document.getElementById("overflow-checker")

fieldset.style.height = "173px"

let prev_height = container.offsetHeight
let momy = 0

setInterval(() => {
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

fetch("/storage_used").then(async result => {
	document.getElementById("storage-used").innerText = "Storage used: " + (result.status == 200
		? await result.text()
		: "error!")
})
