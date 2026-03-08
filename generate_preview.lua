--[[
Create thumbnails plugin for darktable
  darktable is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  darktable is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[About this Plugin
This plugin adds the buttons 'create thumbnails' and 'delete thumbnails' to 'selected image[s]' module of darktable's lighttable view.
----USAGE----
Click the 'create thumbnails' button in the 'selected image[s]' module to let the script create full sized previews of all selected images.
Click the 'delete thumbnails' button in the 'selected image[s]' module to let the script delete all previews/thumbnails of all selected images.
To create (or delete) previews of all images of a collection:
Use CTRL+A to select all images of current collection and then press the corresponding button.
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("8.0.0", "create_thumbnails_button")

local PREFS_NAMESPACE = "create_thumbnails_button"
local THUMBNAIL_LEVELS = {
    { level = 0, label = "level 0 (180x110)" },
    { level = 1, label = "level 1 (360x225)" },
    { level = 2, label = "level 2 (720x450)" },
    { level = 3, label = "level 3 (1440x900)" },
    { level = 4, label = "level 4 (1920x1200)" },
    { level = 5, label = "level 5 (2560x1600)" },
    { level = 6, label = "level 6 (4096x2560)" },
    { level = 7, label = "level 7 (5120x3200)" },
    { level = 8, label = "level 8 (full size)" }
}

for _, level_definition in ipairs(THUMBNAIL_LEVELS) do
    local level = level_definition.level
    dt.preferences.register(
        PREFS_NAMESPACE,
        "generate_level_" .. level,
        "bool",
        "generate thumbnail " .. level_definition.label,
        "create cache level " .. level_definition.label .. " when running 'create thumbnails'",
        true
    )
end

-- stop running thumbnail creation
local function stop_job(job)
    job.valid = false
end

-- return "1 image" if amount_of_images is 1 else "<amount_of_images> images"
local function image_count_to_text(amount_of_images)
    return amount_of_images .. " image" .. (amount_of_images == 1 and "" or "s")
end

-- print the given message to the user and log the given message
local function print_and_log(message)
    dt.print(message)
    dt.print_log(message)
end

local function get_selected_thumbnail_levels()
    local selected_levels = {}

    for _, level_definition in ipairs(THUMBNAIL_LEVELS) do
        local level = level_definition.level
        local enabled = dt.preferences.read(PREFS_NAMESPACE, "generate_level_" .. level, "bool")
        if enabled then
            selected_levels[#selected_levels + 1] = level
        end
    end

    return selected_levels
end

local function levels_to_text(levels)
    local level_texts = {}

    for _, level in ipairs(levels) do
        level_texts[#level_texts + 1] = tostring(level)
    end

    return table.concat(level_texts, ",")
end

-- add button to 'selected images' module
dt.gui.libs.image.register_action(
    "create_thumbnails_button",
    "create thumbnails",
    function(event, images)
        local selected_levels = get_selected_thumbnail_levels()

        if #selected_levels == 0 then
            print_and_log("creating thumbnails canceled: no thumbnail sizes selected in preferences.")
            return
        end

        print_and_log("creating thumbnail levels [" .. levels_to_text(selected_levels) .. "] for " .. image_count_to_text(#images) .. " ...")

        -- create a new progress_bar displayed in darktable.gui.libs.backgroundjobs
        job = dt.gui.create_job("creating thumbnails...", true, stop_job)

        for i, image in pairs(images) do
            -- generate selected thumbnail levels
            -- check only once if the mipmap cache directories exist
            local check_cache_directories = i == 1
            for _, level in ipairs(selected_levels) do
                image:generate_cache(check_cache_directories, level, level)
                check_cache_directories = false
            end

            -- update progress_bar
            job.percent = i / #images

            -- sleep for a short moment to give stop_job callback function a chance to run
            dt.control.sleep(10)

            -- stop early if darktable is shutdown or the cancle button of the progress bar is pressed
            if dt.control.ending or not job.valid then
                print_and_log("creating thumbnails canceled after processing " .. i .. "/" .. image_count_to_text(#images) .. "!")
                break
            end
        end

        -- if job was not canceled
        if(job.valid) then
            -- stop job and remove progress_bar from ui
            job.valid = false

            print_and_log("creating thumbnail levels [" .. levels_to_text(selected_levels) .. "] for " ..  image_count_to_text(#images) .. " done!")
        end
    end,
    "create selected preview/thumbnail sizes of all selected images"
)


-- add button to 'selected images' module
dt.gui.libs.image.register_action(
    "delete_thumbnails_button",
    "delete thumbnails",
    function(event, images)
        print_and_log("deleting thumbnails of " .. image_count_to_text(#images) .. " ...")

        -- create a new progress_bar displayed in darktable.gui.libs.backgroundjobs
        job = dt.gui.create_job("deleting thumbnails...", true, stop_job)

        for i, image in pairs(images) do
            -- delete all thumbnails
            image:drop_cache()

            -- update progress_bar
            job.percent = i / #images

            -- sleep for a short moment to give stop_job callback function a chance to run
            dt.control.sleep(10)

            -- stop early if darktable is shutdown or the cancle button of the progress bar is pressed
            if dt.control.ending or not job.valid then
                print_and_log("deleting thumbnails canceled after processing " .. i .. "/" .. image_count_to_text(#images) .. "!")
                break
            end
        end

        -- if job was not canceled
        if(job.valid) then
            -- stop job and remove progress_bar from ui
            job.valid = false

            print_and_log("deleting thumbnails of " ..  image_count_to_text(#images) .. " done!")
        end
    end,
    "delete all thumbnails of all selected images"
)

-- clean up function that is called when this module is getting disabled
local function destroy()
    dt.gui.libs.image.destroy_action("create_thumbnails_button")
    dt.gui.libs.image.destroy_action("delete_thumbnails_button")
end


local script_data = {}
script_data.destroy = destroy -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
return script_data
