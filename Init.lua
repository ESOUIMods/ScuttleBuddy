ScuttleBuddy = {}

--[[
Some settings moved to Init.lua to make them global to other files
]]--

--[[ Previous var to toggle map pins
ScuttleBuddy_defaults = {
    show_pins=true,
}

-- Saved Vars
ScuttleBuddy_SavedVars.show_pins
]]--
ScuttleBuddy.addon_name = "ScuttleBuddy"
ScuttleBuddy.addon_version = "1.00"
ScuttleBuddy.addon_website = "https://www.esoui.com/downloads/info2647-ScuttleBuddy.html"
ScuttleBuddy.custom_compass_pin = "compass_digsite" -- custom compas pin pin type
ScuttleBuddy.ScuttleBuddy_map_pin = "ScuttleBuddy_map_pin"
ScuttleBuddy.dig_site_pin = "dig_site_pin"
ScuttleBuddy.client_lang = GetCVar("language.2")
ScuttleBuddy.should_update_digsites = true

ScuttleBuddy.pin_textures = {
    [1] = "ScuttleBuddy/img/harvest_scuttlebloom.dds",
}

function ScuttleBuddy.unpack_color_table(the_table)
    local col_r, col_g, col_b, col_a = unpack(the_table)
    return col_r, col_g, col_b, col_a
end

function ScuttleBuddy.create_color_table(r, g, b, a)
    local c = {}

    if(type(r) == "string") then
        c[4], c[1], c[2], c[3] = ConvertHTMLColorToFloatValues(r)
    elseif(type(r) == "table") then
        local otherColorDef = r
        c[1] = otherColorDef.r or 1
        c[2] = otherColorDef.g or 1
        c[3] = otherColorDef.b or 1
        c[4] = otherColorDef.a or 1
    else
        c[1] = r or 1
        c[2] = g or 1
        c[3] = b or 1
        c[4] = a or 1
    end

    return c
end

ScuttleBuddy.ScuttleBuddy_defaults = {
    ["pin_level"] = 30,
    ["pin_size"] = 25,
    ["digsite_pin_size"] = 25,
    ["pin_type"] = 1,
    ["digsite_pin_type"] = 1,
    ["compass_max_distance"] = 0.05,
	["filters"] = {
		[ScuttleBuddy.custom_compass_pin] = true, -- toggle show pin on compass
		[ScuttleBuddy.ScuttleBuddy_map_pin] = true, -- toggle show pin on world map
		[ScuttleBuddy.dig_site_pin] = true, -- toggle show 3d pin in overland
	},
    ["digsite_spike_color"] = {
        [1] = 1,
        [2] = 1,
        [3] = 1,
        [4] = 1,
    },
}
