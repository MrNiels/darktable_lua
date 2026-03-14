local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("8.0.0", "generate_thumbnails")

local gettext = dt.gettext.gettext

local function _(msgid)
	return gettext(msgid)
end

local MODULE_NAME = "generate_thumbnails"
local LIB_ID = "generate_thumbnails_gui"

local THUMBNAIL_LEVELS = {
	{ level = 0, label = _("level 0 (180x110)") },
	{ level = 1, label = _("level 1 (360x225)") },
	{ level = 2, label = _("level 2 (720x450)") },
	{ level = 3, label = _("level 3 (1440x900)") },
	{ level = 4, label = _("level 4 (1920x1200)") },
	{ level = 5, label = _("level 5 (2560x1600)") },
	{ level = 6, label = _("level 6 (4096x2560)") },
	{ level = 7, label = _("level 7 (5120x3200)") },
	{ level = 8, label = _("level 8 (full size)") }
}

local wg = {}

wg.level_0 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[1].label, value = true}
wg.level_1 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[2].label, value = true}
wg.level_2 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[3].label, value = true}
wg.level_3 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[4].label, value = true}
wg.level_4 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[5].label, value = true}
wg.level_5 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[6].label, value = true}
wg.level_6 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[7].label, value = true}
wg.level_7 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[8].label, value = true}
wg.level_8 = dt.new_widget("check_button"){label = THUMBNAIL_LEVELS[9].label, value = true}

local function stop_job(job)
	job.valid = false
end

local function image_count_to_text(image_count)
	return image_count .. " image" .. (image_count == 1 and "" or "s")
end

local function print_and_log(message)
	dt.print(message)
	dt.print_log(message)
end

local function get_action_images()
	return dt.gui.action_images
end

local function get_selected_levels()
	local levels = {}

	if wg.level_0.value then levels[#levels + 1] = THUMBNAIL_LEVELS[1].level end
	if wg.level_1.value then levels[#levels + 1] = THUMBNAIL_LEVELS[2].level end
	if wg.level_2.value then levels[#levels + 1] = THUMBNAIL_LEVELS[3].level end
	if wg.level_3.value then levels[#levels + 1] = THUMBNAIL_LEVELS[4].level end
	if wg.level_4.value then levels[#levels + 1] = THUMBNAIL_LEVELS[5].level end
	if wg.level_5.value then levels[#levels + 1] = THUMBNAIL_LEVELS[6].level end
	if wg.level_6.value then levels[#levels + 1] = THUMBNAIL_LEVELS[7].level end
	if wg.level_7.value then levels[#levels + 1] = THUMBNAIL_LEVELS[8].level end
	if wg.level_8.value then levels[#levels + 1] = THUMBNAIL_LEVELS[9].level end

	return levels
end

local function levels_to_text(levels)
	local texts = {}
	for _, level in ipairs(levels) do
		texts[#texts + 1] = tostring(level)
	end
	return table.concat(texts, ",")
end

local function generate_thumbnails()
	local images = get_action_images()

	if #images == 0 then
		print_and_log(_("no images selected"))
		return
	end

	local selected_levels = get_selected_levels()
	if #selected_levels == 0 then
		print_and_log(_("no thumbnail sizes selected"))
		return
	end

	print_and_log(_("creating thumbnail levels") .. " [" .. levels_to_text(selected_levels) .. "] " ..
		_("for") .. " " .. image_count_to_text(#images) .. " ...")

	local job = dt.gui.create_job(_("creating thumbnails..."), true, stop_job)

	for i, image in ipairs(images) do
		local check_cache_directories = i == 1
		for _, level in ipairs(selected_levels) do
			image:generate_cache(check_cache_directories, level, level)
			check_cache_directories = false
		end

		job.percent = i / #images
		dt.control.sleep(10)

		if dt.control.ending or not job.valid then
			print_and_log(_("creating thumbnails canceled after processing") .. " " .. i .. "/" .. image_count_to_text(#images) .. "!")
			return
		end
	end

	job.valid = false
	print_and_log(_("creating thumbnail levels") .. " [" .. levels_to_text(selected_levels) .. "] " ..
		_("for") .. " " .. image_count_to_text(#images) .. " " .. _("done") .. "!")
end

local function remove_thumbnails()
	local images = get_action_images()

	if #images == 0 then
		print_and_log(_("no images selected"))
		return
	end

	print_and_log(_("deleting thumbnails for") .. " " .. image_count_to_text(#images) .. " ...")

	local job = dt.gui.create_job(_("deleting thumbnails..."), true, stop_job)

	for i, image in ipairs(images) do
		image:drop_cache()

		job.percent = i / #images
		dt.control.sleep(10)

		if dt.control.ending or not job.valid then
			print_and_log(_("deleting thumbnails canceled after processing") .. " " .. i .. "/" .. image_count_to_text(#images) .. "!")
			return
		end
	end

	job.valid = false
	print_and_log(_("deleting thumbnails for") .. " " .. image_count_to_text(#images) .. " " .. _("done") .. "!")
end

dt.register_lib(
	LIB_ID,
	_("generate thumbnails"),
	true,
	false,
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
	dt.new_widget("box"){
		orientation = "vertical",
		dt.new_widget("label"){label = _("thumbnail sizes")},
		wg.level_0,
		wg.level_1,
		wg.level_2,
		wg.level_3,
		wg.level_4,
		wg.level_5,
		wg.level_6,
		wg.level_7,
		wg.level_8,
		dt.new_widget("button"){
			label = _("generate thumbnails"),
			tooltip = _("generate selected thumbnail sizes for selected images"),
			clicked_callback = function()
				generate_thumbnails()
			end
		},
		dt.new_widget("button"){
			label = _("remove thumbnails"),
			tooltip = _("remove all thumbnails for selected images"),
			clicked_callback = function()
				remove_thumbnails()
			end
		}
	}
)

local function restart()
	dt.gui.libs[LIB_ID].visible = true
end

local function destroy()
	dt.gui.libs[LIB_ID].visible = false
end

local script_data = {}

script_data.metadata = {
	name = _("generate thumbnails"),
	purpose = _("generate or remove thumbnails from a right panel gui in lighttable"),
	author = "mr_niels",
	help = ""
}

script_data.destroy = destroy
script_data.destroy_method = "hide"
script_data.restart = restart
script_data.show = restart

return script_data
