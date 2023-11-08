const password_check = document.getElementById("password-check")
const total_text = document.getElementById("total-text")

let table, mouse_enter_link, mouse_leave_link
function generate_table(favourites, others, regex = /.*/) {
	table.innerHTML = "Loading..."
	let i = 0
	let html = "<tr>"
	let favourites_left = favourites.length
	for (const [link, filename] of [...favourites, ...others]) {
		favourites_left--
		if (regex.test(filename)) {
			if (!(i++ % 3))
				html += "</tr><tr>"
			const a = `<a href="${link}" class="link">${filename}</a>`
			html += favourites_left >= 0
				? `<td class="file"><span class="favourite">❤</span>${a}</td>`
				: `<td class="file">${a}</td>`
		}
	}
	table.innerHTML = html + "</tr>"
	const color = total_text.style.animation.match(/fade\-\w+\-\w+$/)
	if (color)
		document.querySelectorAll(".file, .link, .favourite")
			.forEach(element => element.style.animation = `${color} 0s linear forwards`)
	Array.from(document.getElementsByClassName("link")).forEach(link => {
		link.filename = link.pathname
		link.addEventListener("mouseenter", mouse_enter_link)
		link.addEventListener("mouseleave", mouse_leave_link)
	})
	total_text.innerText = `${i} files total`
}

password_check.addEventListener("submit", async e => {
	e.preventDefault()
	const result = await fetch("/files", {
		method: "GET",
		headers: {
			Password: document.getElementById("password").value
		}
	})
	if (result.status != 200) {
		document.write(await result.text().replace("/index.html", "/files.html"))
		return
	}
	const { favourites, others } = await result.json()
	password_check.remove()
	const title = document.getElementById("title")
	title.innerText = "Currently uploaded files"
	table = document.createElement("table")
	document.getElementById("file-list").appendChild(table)
	const filter_span = document.getElementById("file-filter")
	const filters = document.getElementsByClassName("filter")
	const filter_text = filters[0].firstElementChild
	const filter_favourites = filters[1].firstElementChild
	const filter_others = filters[2].firstElementChild
	const filter_regex = filters[3].firstElementChild
	filter_span.style.display = "inline"
	filter_span.addEventListener("input", () => {
		try {
			generate_table(
				filter_favourites.checked ? favourites : [],
				filter_others.checked ? others : [],
				filter_text.value != ""
					? (filter_regex.checked
						? new RegExp(filter_text.value)
						: new RegExp(filter_text.value.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')))
					: undefined
			)
		} catch (err) {
			total_text.innerText = err
			table.innerHTML = ""
		}
	})
	const img = document.getElementsByClassName("preview-file")[0]
	const preview_text = document.getElementById("preview-text")
	img.style.opacity = "0"
	let target_opacity = 0
	let next_target_opacity = 0
	let path = "/files"
	let old_src
	mouse_enter_link = async e => {
		const link = e.target
		preview_text.innerText = "Loading..."
		link.href = path + link.filename
		preview_text.style.animation = "fade-in 140ms linear forwards"
		old_src = img.src
		img.src = "/files" + link.filename
		img.errored = false
		next_target_opacity = 1
		const head_result = await fetch(img.src, { method: "HEAD" })
		preview_text.innerText = "Upload date: " + (head_result.status == 200
			? new Date(parseInt(head_result.headers.get("Upload-Date"))).toLocaleString()
			: "???")
		const edit_date = head_result.headers.get("Edit-Date")
		if (edit_date) {
			preview_text.innerText += "\nEdit date: " + new Date(parseInt(edit_date)).toLocaleString()
		}
		const delete_date = head_result.headers.get("Delete-Date")
		if (delete_date) {
			preview_text.innerText += "\nDelete date: " + new Date(parseInt(delete_date)).toLocaleString()
		}
	}
	mouse_leave_link = () => {
		preview_text.style.animation = "fade-out 140ms linear forwards"
		next_target_opacity = 0
		target_opacity = 0
	}
	img.addEventListener("error", () => {
		if (img.errored) return
		img.errored = true
		img.src = old_src
		target_opacity = 0
		next_target_opacity = 0
	})
	img.addEventListener("load", () => {
		target_opacity = next_target_opacity
	})
	setInterval(() => {
		const opacity = parseFloat(img.style.opacity)
		if (opacity < target_opacity) {
			img.style.opacity = opacity + 0.05
		} else if (opacity > target_opacity) {
			img.style.opacity = opacity - 0.05					
		}
	}, 7)
	generate_table(favourites, others)
	const delete_button = document.getElementById("delete-button")
	const replace_button = document.getElementById("replace-button")
	delete_button.og_name = delete_button.innerText
	replace_button.og_name = replace_button.innerText
	delete_button.classList.remove("disabled-button")
	replace_button.classList.remove("disabled-button")
	function setup_button(button, other, cancellation, new_path, color, other_color) {
		button.addEventListener("click", () => {
			switch (button.innerText) {
				case button.og_name: {
					path = new_path
					title.innerText = `Select file to ${cancellation}...`
					button.innerText = `Cancel ${cancellation}`
					preview_text.style.color = color
					preview_text.style.opacity = "0"
					const animation = other.innerText == other.og_name
						? `fade-white-${color} 0.5s linear forwards`
						: `fade-${other_color}-${color} 0.5s linear forwards`
					document.querySelectorAll("*").forEach(element => {
						element.style.animation = animation
					})
					other.innerText = other.og_name
					break
				}
				case `Cancel ${cancellation}`: {
					path = "/files/"
					title.innerText = "Currently uploaded files"
					button.innerText = button.og_name
					preview_text.style.color = "white"
					preview_text.style.opacity = "0"
					document.querySelectorAll("*").forEach(element => {
						element.style.animation = `fade-${color}-white 0.5s linear forwards`
					})
					break
				}
			}
		})
	}
	setup_button(delete_button, replace_button, "delete", "/delete.html?file=", "red", "yellow")
	setup_button(replace_button, delete_button, "replace", "/replace.html?file=", "yellow", "red")
})
