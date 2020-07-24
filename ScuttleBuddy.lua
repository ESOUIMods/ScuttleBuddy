local LMP = LibMapPins
local GPS = LibGPS3
local Lib3D = Lib3D
local CCP = COMPASS_PINS
local LAM = LibAddonMenu2

---------------------------------------
----- Degub Logging               -----
---------------------------------------

if LibDebugLogger then
    local logger = LibDebugLogger.Create(ScuttleBuddy.addon_name)
    ScuttleBuddy.logger = logger
end
ScuttleBuddy.show_log = true
local SDLV = DebugLogViewer

local function create_log(log_type, log_content)
    if ScuttleBuddy.show_log and ScuttleBuddy.logger and SDLV then
        if log_type == "Debug" then
            ScuttleBuddy.logger:Debug(log_content)
        end
        if log_type == "Verbose" then
            ScuttleBuddy.logger:Verbose(log_content)
        end
    elseif ScuttleBuddy.show_log and not SDLV then
        d(log_content)
    end
end

local function emit_message(log_type, text)
    if(text == "") then
        text = "[Empty String]"
    end
    create_log(log_type, text)
end

local function emit_table(log_type, t, indent, table_history)
    indent          = indent or "."
    table_history    = table_history or {}

    for k, v in pairs(t) do
        local vType = type(v)

        emit_message(log_type, indent.."("..vType.."): "..tostring(k).." = "..tostring(v))

        if(vType == "table") then
            if(table_history[v]) then
                emit_message(log_type, indent.."Avoiding cycle on table...")
            else
                table_history[v] = true
                emit_table(log_type, v, indent.."  ", table_history)
            end
        end
    end
end

function ScuttleBuddy.dm(log_type, ...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if(type(value) == "table") then
            emit_table(log_type, value)
        else
            emit_message(log_type, tostring(value))
        end
    end
end

---------------------------------------
----- ScuttleBuddy Vars                -----
---------------------------------------

ScuttleBuddy_SavedVars = ScuttleBuddy_SavedVars or { }
ScuttleBuddy_SavedVars.version = ScuttleBuddy_SavedVars.version or 1 -- This is not the addon version number
ScuttleBuddy_SavedVars.location_info = ScuttleBuddy_SavedVars.location_info or { }
ScuttleBuddy_SavedVars.pin_level = ScuttleBuddy_SavedVars.pin_level or ScuttleBuddy.ScuttleBuddy_defaults.pin_level
ScuttleBuddy_SavedVars.pin_size = ScuttleBuddy_SavedVars.pin_size or ScuttleBuddy.ScuttleBuddy_defaults.pin_size
ScuttleBuddy_SavedVars.digsite_pin_size = ScuttleBuddy_SavedVars.digsite_pin_size or ScuttleBuddy.ScuttleBuddy_defaults.digsite_pin_size
ScuttleBuddy_SavedVars.pin_type = ScuttleBuddy_SavedVars.pin_type or ScuttleBuddy.ScuttleBuddy_defaults.pin_type
ScuttleBuddy_SavedVars.digsite_pin_type = ScuttleBuddy_SavedVars.digsite_pin_type or ScuttleBuddy.ScuttleBuddy_defaults.digsite_pin_type
ScuttleBuddy_SavedVars.compass_max_distance = ScuttleBuddy_SavedVars.compass_max_distance or ScuttleBuddy.ScuttleBuddy_defaults.compass_max_distance
ScuttleBuddy_SavedVars.custom_compass_pin = ScuttleBuddy_SavedVars.custom_compass_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.custom_compass_pin]
ScuttleBuddy_SavedVars.ScuttleBuddy_map_pin = ScuttleBuddy_SavedVars.ScuttleBuddy_map_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.ScuttleBuddy_map_pin]
ScuttleBuddy_SavedVars.dig_site_pin = ScuttleBuddy_SavedVars.dig_site_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.dig_site_pin]
ScuttleBuddy_SavedVars.digsite_spike_color = ScuttleBuddy_SavedVars.digsite_spike_color or ScuttleBuddy.ScuttleBuddy_defaults.digsite_spike_color

-- Existing Local
local PIN_TYPE = "pinType_Digsite" -- This is changed by LAM now, use ScuttleBuddy.ScuttleBuddy_map_pin
local PIN_FILTER_NAME = "ScuttleBuddy"
local PIN_NAME = "Scuttle Bloom"
local PIN_PRIORITY_OFFSET = 1

-- ScuttleBuddy
ScuttleBuddy.dig_site_names = {
    ["en"] = "Scuttle Bloom",
}

ScuttleBuddy.loc_index = {
    x_pos  = 1,
    y_pos  = 2,
    x_gps  = 3,
    y_gps  = 4,
    worldX = 5,
    worldY = 6,
    worldZ = 7,
}

local function is_in(search_value, search_table)
    for k, v in pairs(search_table) do
        if search_value == v then return true end
        if type(search_value) == "string" then
            if string.find(string.lower(v), string.lower(search_value)) then return true end
        end
    end
    return false
end

-- Function to check for empty table
local function is_empty_or_nil(t)
    if not t then return true end
    if type(t) == "table" then
        if next(t) == nil then
            return true
        else
            return false
        end
    elseif type(t) == "string" then
        if t == nil then
            return true
        elseif t == "" then
            return true
        else
            return false
        end
    elseif type(t) == "nil" then
        return true
    end
end

local function get_digsite_locations(zone)
    --d(zone)
    if is_empty_or_nil(ScuttleBuddy.locations[zone]) then
        return {}
    else
        return ScuttleBuddy.locations[zone]
    end
end

---------------------------------------
----- ScuttleBuddy                     -----
---------------------------------------
ScuttleBuddy.worldControlPool = ZO_ControlPool:New("ScuttleBuddy_WorldPin", ScuttleBuddy_WorldPins)
ScuttleBuddy.antiquity_locations = {}

local function get_digsite_loc_sv(zone)
    d(zone)
    if is_empty_or_nil(ScuttleBuddy_SavedVars.location_info[zone]) then
        return {}
    else
        return ScuttleBuddy_SavedVars.location_info[zone]
    end
end

local function save_to_sv(locations_table, location)
    --[[
    This should be the table not the Zone like Skyrim or
    the ZoneID

    example ScuttleBuddy.locations[zone_id][zone] where zone might be
    ["skyrim/westernskryim_base_0"] and zone_id is 1160
    ]]--
    local save_location = true
    for num_entry, digsite_loc in ipairs(locations_table) do
        local distance = zo_round(GPS:GetLocalDistanceInMeters(digsite_loc[ScuttleBuddy.loc_index.x_pos], digsite_loc[ScuttleBuddy.loc_index.y_pos], location[ScuttleBuddy.loc_index.x_pos], location[ScuttleBuddy.loc_index.y_pos]))
        --d(distance)
        if distance <= 10 then
            --d("less then 10 to close to me")
            return false
        else
            --d("more then 10, far away, save it")
        end
    end
    return save_location
end

local function save_dig_site_location()
    ScuttleBuddy.dm("Debug", "save_dig_site_location")
    local x_pos, y_pos = GetMapPlayerPosition("player")
    local x_gps, y_gps = GPS:LocalToGlobal(x_pos, y_pos)
    local zone_id, worldX, worldY, worldZ = GetUnitWorldPosition("player")

    local zone = LMP:GetZoneAndSubzone(true, false, true)
    -- if ScuttleBuddy_SavedVars.location_info == nil then ScuttleBuddy_SavedVars.location_info = {} end
    -- not needed, because it's already created above
    ScuttleBuddy_SavedVars.location_info = ScuttleBuddy_SavedVars.location_info or { }
    ScuttleBuddy_SavedVars.location_info[zone] = ScuttleBuddy_SavedVars.location_info[zone] or { }

    if ScuttleBuddy.locations == nil then ScuttleBuddy.locations = {} end
    if ScuttleBuddy.locations[zone] == nil then ScuttleBuddy.locations[zone] = {} end

    local locations_table = get_digsite_locations(zone)
    if is_empty_or_nil(locations_table) then locations_table = {} end

    local locations_sv_table = get_digsite_loc_sv(zone)
    if is_empty_or_nil(locations_sv_table) then locations_sv_table = {} end

    local location = {
        [ScuttleBuddy.loc_index.x_pos] = x_pos,
        [ScuttleBuddy.loc_index.y_pos] = y_pos,
        [ScuttleBuddy.loc_index.x_gps] = x_gps,
        [ScuttleBuddy.loc_index.y_gps] = y_gps,
        [ScuttleBuddy.loc_index.worldX] = worldX,
        [ScuttleBuddy.loc_index.worldY] = worldY,
        [ScuttleBuddy.loc_index.worldZ] = worldZ,
    }
    if save_to_sv(locations_table, location) and save_to_sv(locations_sv_table, location) then
        ScuttleBuddy.dm("Debug", "Saving Location")
        table.insert(ScuttleBuddy_SavedVars.location_info[zone], location)
        LMP:RefreshPins(ScuttleBuddy.ScuttleBuddy_map_pin)
        CCP:RefreshPins(ScuttleBuddy.custom_compass_pin)
        --ScuttleBuddy.Draw3DPins()
    else
        ScuttleBuddy.dm("Debug", "No need to save location")
    end
end

function ScuttleBuddy.RefreshPinLayout()
    LMP:SetLayoutKey(ScuttleBuddy.ScuttleBuddy_map_pin, "size", ScuttleBuddy_SavedVars.pin_size)
    LMP:SetLayoutKey(ScuttleBuddy.ScuttleBuddy_map_pin, "level", ScuttleBuddy_SavedVars.pin_level+PIN_PRIORITY_OFFSET)
    LMP:SetLayoutKey(ScuttleBuddy.ScuttleBuddy_map_pin, "texture", ScuttleBuddy.pin_textures[ScuttleBuddy_SavedVars.pin_type])
end

---------------------------------------
----- Lib3D                       -----
---------------------------------------

function ScuttleBuddy.Hide3DPins()
    -- remove the on update handler and hide the ScuttleBuddy.dig_site_pin
    EVENT_MANAGER:UnregisterForUpdate("DigSite")
    ScuttleBuddy_WorldPins:SetHidden(true)
    ScuttleBuddy.worldControlPool:ReleaseAllObjects()
end

function ScuttleBuddy.Draw3DPins()
    EVENT_MANAGER:UnregisterForUpdate("DigSite")

    local zone = LMP:GetZoneAndSubzone(true, false, true)

    local mapData = ScuttleBuddy.get_pin_data(zone) or { }
    -- pseudo_pin_location
    if mapData then
        local worldX, worldZ, worldY = WorldPositionToGuiRender3DPosition(0,0,0)
        if not worldX then return end
        ScuttleBuddy_WorldPins:Set3DRenderSpaceOrigin(worldX, worldZ, worldY)
        ScuttleBuddy_WorldPins:SetHidden(false)

        for pin, pinData in ipairs(mapData) do
            local pinControl = ScuttleBuddy.worldControlPool:AcquireObject(pin)
            if not pinControl:Has3DRenderSpace() then
                pinControl:Create3DRenderSpace()
            end

            local size = 1
            local iconControl = pinControl:GetNamedChild("Icon")
            if not iconControl:Has3DRenderSpace() then
                iconControl:Create3DRenderSpace()
                iconControl:Set3DRenderSpaceUsesDepthBuffer(true)
            end
            iconControl:SetTexture(ScuttleBuddy.pin_textures[ScuttleBuddy_SavedVars.digsite_pin_type])
            iconControl:Set3DRenderSpaceOrigin(pinData[ScuttleBuddy.loc_index.worldX]/100, (pinData[ScuttleBuddy.loc_index.worldY]/100) + 2.5, pinData[ScuttleBuddy.loc_index.worldZ]/100)
            iconControl:Set3DLocalDimensions(0.30 * size + 0.6, 0.30 * size + 0.6)

            local spikeControl = pinControl:GetNamedChild("Spike")
            if not spikeControl:Has3DRenderSpace() then
                spikeControl:Create3DRenderSpace()
                spikeControl:Set3DRenderSpaceUsesDepthBuffer(true)
            end
            spikeControl:SetColor(ScuttleBuddy.unpack_color_table(ScuttleBuddy_SavedVars.digsite_spike_color))
            spikeControl:Set3DRenderSpaceOrigin(pinData[ScuttleBuddy.loc_index.worldX]/100, (pinData[ScuttleBuddy.loc_index.worldY]/100) + 1.0, pinData[ScuttleBuddy.loc_index.worldZ]/100)
            spikeControl:Set3DLocalDimensions(0.25 * size + 0.75, 0.75 * size + 1.25)
        end

        local activeObjects = ScuttleBuddy.worldControlPool:GetActiveObjects()

        -- don't do that every single frame. it's not necessary
        EVENT_MANAGER:RegisterForUpdate("DigSite", 100, function()
            local x, y, z, forwardX, forwardY, forwardZ, rightX, rightY, rightZ, upX, upY, upZ = Lib3D:GetCameraRenderSpace()
            for key, pinControl in pairs(activeObjects) do
                for i = 1, pinControl:GetNumChildren() do
                    local textureControl = pinControl:GetChild(i)
                    textureControl:Set3DRenderSpaceForward(forwardX, forwardY, forwardZ)
                    textureControl:Set3DRenderSpaceRight(rightX, rightY, rightZ)
                    textureControl:Set3DRenderSpaceUp(upX, upY, upZ)
                end
            end
        end)
    end
end

local function OnInteract(event_code, client_interact_result, interact_target_name)
    ScuttleBuddy.dm("Debug", "OnInteract Occured")
    --d(client_interact_result)
    local text = zo_strformat(SI_CHAT_MESSAGE_FORMATTER, interact_target_name)
    ScuttleBuddy.dm("Debug", text)
    ScuttleBuddy.dm("Debug", "OnInteract")
    if text == ScuttleBuddy.dig_site_names[ScuttleBuddy.client_lang] then
        ScuttleBuddy.dm("Debug", "ScuttleBuddy.dig_site_names")
        save_dig_site_location()
    end
    ScuttleBuddy.update_active_locations()
end
EVENT_MANAGER:RegisterForEvent(ScuttleBuddy.addon_name,EVENT_CLIENT_INTERACT_RESULT, OnInteract)

function ScuttleBuddy.combine_data(zone)
    ScuttleBuddy_SavedVars.location_info = ScuttleBuddy_SavedVars.location_info or { }
    ScuttleBuddy_SavedVars.location_info[zone] = ScuttleBuddy_SavedVars.location_info[zone] or { }

    ScuttleBuddy.locations[zone] = ScuttleBuddy.locations[zone] or { }

    local mapData = ScuttleBuddy.locations[zone] or { }
    local locations_sv_table = get_digsite_loc_sv(zone) or { }
    for num_entry, digsite_loc in ipairs(locations_sv_table) do
        if save_to_sv(mapData, digsite_loc) then
            table.insert(mapData, digsite_loc)
        end
    end
    return mapData
end

function ScuttleBuddy.get_pin_data(zone)
    local function digsite_in_range(location)
        for key, compas_pin_loc in pairs(ScuttleBuddy.antiquity_locations) do
            local distance = zo_round(GPS:GetLocalDistanceInMeters(compas_pin_loc.x, compas_pin_loc.y, location[ScuttleBuddy.loc_index.x_pos], location[ScuttleBuddy.loc_index.y_pos]))
            if distance <= ScuttleBuddy.antiquity_locations[key].size then
                return true
            end
        end
        return false
    end

    local function in_mod_digsite_pool(main_table, location)
        for _, compas_pin_loc in pairs(main_table) do
            local distance = zo_round(GPS:GetLocalDistanceInMeters(compas_pin_loc[ScuttleBuddy.loc_index.x_pos], compas_pin_loc[ScuttleBuddy.loc_index.y_pos], location[ScuttleBuddy.loc_index.x_pos], location[ScuttleBuddy.loc_index.y_pos]))
            if distance <= 10 then
                return true
            end
        end
        return false
    end

    ScuttleBuddy_SavedVars.location_info = ScuttleBuddy_SavedVars.location_info or { }
    ScuttleBuddy_SavedVars.location_info[zone] = ScuttleBuddy_SavedVars.location_info[zone] or { }

    ScuttleBuddy.locations[zone] = ScuttleBuddy.locations[zone] or { }

    -- this is the end result if within range
    local mod_digsite_pool = { }

    for num_entry, digsite_loc in ipairs(ScuttleBuddy.locations[zone]) do
        if digsite_in_range(digsite_loc) then
            table.insert(mod_digsite_pool, digsite_loc)
        end
    end

    local locations_sv_table = get_digsite_loc_sv(zone) or { }
    for num_entry, digsite_loc in ipairs(locations_sv_table) do
        if digsite_in_range(digsite_loc) and not in_mod_digsite_pool(mod_digsite_pool, digsite_loc) then
            table.insert(mod_digsite_pool, digsite_loc)
        end
    end

    mod_digsite_pool = ScuttleBuddy.combine_data(zone)
    return mod_digsite_pool
end

local function InitializePins()
    local function MapPinAddCallback(pinType)
        local zone = LMP:GetZoneAndSubzone(true, false, true)
        --[[
        Problem encountered. When standing in the ["skyrim/solitudeoutlawsrefuge_0"]

        The Zone ID for that map is 1178 and the mapname is ["skyrim/solitudeoutlawsrefuge_0"]

        If you have the map open and change maps, then the map might be ["craglorn/craglorn_base_0"]
        but the player, where they are currently standing is still 1178.

        meaning the game will look for 1178 and ["craglorn/craglorn_base_0"] which is invalid
        ]]--
        --d(zone)
        local mapData = ScuttleBuddy.get_pin_data(zone) or { }
        if mapData then
            for index, pinData in pairs(mapData) do
                LMP:CreatePin(ScuttleBuddy.ScuttleBuddy_map_pin, pinData, pinData[ScuttleBuddy.loc_index.x_pos], pinData[ScuttleBuddy.loc_index.y_pos])
            end
        end
    end

    local function PinTypeAddCallback(pinType)
        if GetMapType() <= MAPTYPE_ZONE and LMP:IsEnabled(pinType) then
            MapPinAddCallback(pinType)
        end
    end

    local lmp_pin_layout =
    {
        level = ScuttleBuddy_SavedVars.pin_level,
        texture = ScuttleBuddy.pin_textures[ScuttleBuddy_SavedVars.pin_type],
        size = ScuttleBuddy_SavedVars.pin_size,
    }

    local pinlayout_compass = {
        maxDistance = 0.05,
        texture = ScuttleBuddy.pin_textures[ScuttleBuddy_SavedVars.custom_compass_pin],
        sizeCallback = function(pin, angle, normalizedAngle, normalizedDistance)
            if zo_abs(normalizedAngle) > 0.25 then
                pin:SetDimensions(54 - 24 * zo_abs(normalizedAngle), 54 - 24 * zo_abs(normalizedAngle))
            else
                pin:SetDimensions(48, 48)
            end
        end,
    }

    local function compass_callback()
        if GetMapType() <= MAPTYPE_ZONE and ScuttleBuddy_SavedVars.custom_compass_pin then
            local zone = LMP:GetZoneAndSubzone(true, false, true)
            local mapData = ScuttleBuddy.get_pin_data(zone) or { }
            if mapData then
                for _, pinData in ipairs(mapData) do
                    CCP.pinManager:CreatePin(ScuttleBuddy.custom_compass_pin, pinData, pinData[ScuttleBuddy.loc_index.x_pos], pinData[ScuttleBuddy.loc_index.y_pos])
                end
            end
        end
    end

    local pinTooltipCreator = {
        creator = function(pin)
            if IsInGamepadPreferredMode() then
                local InformationTooltip = ZO_MapLocationTooltip_Gamepad
                local baseSection = InformationTooltip.tooltip
                InformationTooltip:LayoutIconStringLine(baseSection, nil, ScuttleBuddy.addon_name, baseSection:GetStyle("mapLocationTooltipContentHeader"))
                InformationTooltip:LayoutIconStringLine(baseSection, nil, PIN_NAME, baseSection:GetStyle("mapLocationTooltipContentName"))
            else
                SetTooltipText(InformationTooltip, PIN_NAME)
            end
        end
    }

    LMP:AddPinType(ScuttleBuddy.ScuttleBuddy_map_pin, function() PinTypeAddCallback(ScuttleBuddy.ScuttleBuddy_map_pin) end, nil, lmp_pin_layout, pinTooltipCreator)
    ScuttleBuddy.RefreshPinLayout()
    LMP:RefreshPins(ScuttleBuddy.ScuttleBuddy_map_pin)
    CCP:AddCustomPin(ScuttleBuddy.custom_compass_pin, compass_callback, pinlayout_compass)
    CCP:RefreshPins(ScuttleBuddy.custom_compass_pin)
end

local function build_zone_data()
    local zone = LMP:GetZoneAndSubzone(true, false, true)
    if ScuttleBuddy_SavedVars.data_store == nil then ScuttleBuddy_SavedVars.data_store = {} end
    ScuttleBuddy_SavedVars.data_store[zone] = ScuttleBuddy.combine_data(zone)
end

local function build_all_zone_data()
    local all_internal_data = ZO_DeepTableCopy(ScuttleBuddy.locations)
    local all_savedvariables_data = ZO_DeepTableCopy(ScuttleBuddy_SavedVars["location_info"])
    local current_internal_zone
    ScuttleBuddy_SavedVars.data_store = {}

    for zone, zone_data in pairs(all_internal_data) do
        if not is_empty_or_nil(zone_data) then
            if ScuttleBuddy_SavedVars.data_store[zone] == nil then ScuttleBuddy_SavedVars.data_store[zone] = {} end
            ScuttleBuddy_SavedVars.data_store[zone] = zone_data
        end
    end

    for zone, zone_data in pairs(all_savedvariables_data) do
        current_internal_zone = get_digsite_locations(zone)
        if not is_empty_or_nil(current_internal_zone) then
            for index, location_data in pairs(zone_data) do
                if save_to_sv(current_internal_zone, location_data) then
                    if ScuttleBuddy_SavedVars.data_store[zone] == nil then ScuttleBuddy_SavedVars.data_store[zone] = {} end
                    table.insert(ScuttleBuddy_SavedVars.data_store[zone], location_data)
                end
            end
        end
    end
end

local function reset_zone_data()
    ScuttleBuddy_SavedVars.data_store = nil
    ScuttleBuddy_SavedVars.cleaned_data_store = nil
end

local function OnPlayerActivated(eventCode)
    ScuttleBuddy.RefreshPinLayout()
    CCP.pinLayouts[ScuttleBuddy.custom_compass_pin].maxDistance = ScuttleBuddy_SavedVars.compass_max_distance
    CCP.pinLayouts[ScuttleBuddy.custom_compass_pin].texture = ScuttleBuddy.pin_textures[ScuttleBuddy_SavedVars.pin_type]
    CCP:RefreshPins(ScuttleBuddy.custom_compass_pin)
    ScuttleBuddy.update_active_locations()
    --ScuttleBuddy.Draw3DPins()
    EVENT_MANAGER:UnregisterForEvent(ScuttleBuddy.addon_name.."_InitPins", EVENT_PLAYER_ACTIVATED)
end
EVENT_MANAGER:RegisterForEvent(ScuttleBuddy.addon_name.."_InitPins", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

function ScuttleBuddy.update_active_locations()
    ScuttleBuddy.dm("Debug", "update_active_locations")
    ScuttleBuddy_SavedVars.custom_compass_pin = true
    -- also enable map pins
    ScuttleBuddy_SavedVars.ScuttleBuddy_map_pin = true

    LMP:Enable(ScuttleBuddy.ScuttleBuddy_map_pin)
    LMP:RefreshPins(ScuttleBuddy.ScuttleBuddy_map_pin)
    CCP:RefreshPins(ScuttleBuddy.custom_compass_pin)
    --[[
        ScuttleBuddy.Draw3DPins()
    else
        ScuttleBuddy.Hide3DPins()
    end
    ]]--
end

local function purge_duplicate_data()
    local all_savedvariables_data = ZO_DeepTableCopy(ScuttleBuddy_SavedVars["location_info"])
    local current_internal_zone
    ScuttleBuddy_SavedVars.location_info = {}
    for zone, zone_data in pairs(all_savedvariables_data) do
        current_internal_zone = get_digsite_locations(zone)
        if not is_empty_or_nil(current_internal_zone) then
            ScuttleBuddy.dm("Debug", "loop over locations")
            for index, location_data in pairs(zone_data) do
                if save_to_sv(current_internal_zone, location_data) then
                    if ScuttleBuddy_SavedVars.location_info[zone] == nil then ScuttleBuddy_SavedVars.location_info[zone] = {} end
                    table.insert(ScuttleBuddy_SavedVars.location_info[zone], location_data)
                end
            end
        else
            ScuttleBuddy.dm("Debug", "ScuttleBuddy nothing to loop over")
            ScuttleBuddy_SavedVars.location_info[zone] = all_savedvariables_data[zone]
        end
    end
end

local function OnLoad(eventCode, addOnName)
    if addOnName ~= ScuttleBuddy.addon_name then return end
    -- turn the top level control into a 3d control
    ScuttleBuddy_WorldPins:Create3DRenderSpace()

    -- make sure the control is only shown, when the player can see the world
    -- i.e. the control is only shown during non-menu scenes
    local fragment = ZO_SimpleSceneFragment:New(ScuttleBuddy_WorldPins)
    HUD_UI_SCENE:AddFragment(fragment)
    HUD_SCENE:AddFragment(fragment)
    LOOT_SCENE:AddFragment(fragment)

    -- register a callback, so we know when to start/stop displaying the ScuttleBuddy.dig_site_pin
    Lib3D:RegisterWorldChangeCallback("DigSite", function(identifier, zoneIndex, isValidZone, newZone)
        if not newZone then return end
        
        --[[
            ScuttleBuddy.Draw3DPins()
        else
            ScuttleBuddy.Hide3DPins()
        end
        ]]--
    end)

    if ScuttleBuddy_SavedVars.version ~= 4 then
        local temp_locations
        if ScuttleBuddy_SavedVars.version == nil then ScuttleBuddy_SavedVars.version = 1 end
        if ScuttleBuddy_SavedVars.version >= 2 then
            if ScuttleBuddy_SavedVars.location_info then
                temp_locations = ScuttleBuddy_SavedVars.location_info
            end
        end
        ScuttleBuddy_SavedVars = { }
        ScuttleBuddy_SavedVars.version = 4
        ScuttleBuddy_SavedVars.location_info = temp_locations or { }
        ScuttleBuddy_SavedVars.pin_level = ScuttleBuddy_SavedVars.pin_level or ScuttleBuddy.ScuttleBuddy_defaults.pin_level
        ScuttleBuddy_SavedVars.pin_size = ScuttleBuddy_SavedVars.pin_size or ScuttleBuddy.ScuttleBuddy_defaults.pin_size
        ScuttleBuddy_SavedVars.digsite_pin_size = ScuttleBuddy_SavedVars.digsite_pin_size or ScuttleBuddy.ScuttleBuddy_defaults.digsite_pin_size
        ScuttleBuddy_SavedVars.pin_type = ScuttleBuddy_SavedVars.pin_type or ScuttleBuddy.ScuttleBuddy_defaults.pin_type
        ScuttleBuddy_SavedVars.digsite_pin_type = ScuttleBuddy_SavedVars.digsite_pin_type or ScuttleBuddy.ScuttleBuddy_defaults.digsite_pin_type
        ScuttleBuddy_SavedVars.compass_max_distance = ScuttleBuddy_SavedVars.compass_max_distance or ScuttleBuddy.ScuttleBuddy_defaults.compass_max_distance
        ScuttleBuddy_SavedVars.custom_compass_pin = ScuttleBuddy_SavedVars.custom_compass_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.custom_compass_pin]
        ScuttleBuddy_SavedVars.ScuttleBuddy_map_pin = ScuttleBuddy_SavedVars.ScuttleBuddy_map_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.ScuttleBuddy_map_pin]
        ScuttleBuddy_SavedVars.dig_site_pin = ScuttleBuddy_SavedVars.dig_site_pin or ScuttleBuddy.ScuttleBuddy_defaults.filters[ScuttleBuddy.dig_site_pin]
        if ScuttleBuddy_SavedVars.version >= 4 then
            ScuttleBuddy_SavedVars.digsite_spike_color = ScuttleBuddy_SavedVars.digsite_spike_color or ScuttleBuddy.ScuttleBuddy_defaults.digsite_spike_color
        else
            ScuttleBuddy_SavedVars.digsite_spike_color = ScuttleBuddy.ScuttleBuddy_defaults.digsite_spike_color
        end
    end

    if ScuttleBuddy_SavedVars["location_info"]["eyevea_base_0"] then
        ScuttleBuddy_SavedVars["location_info"]["guildmaps/eyevea_base_0"] = ScuttleBuddy_SavedVars["location_info"]["eyevea_base_0"]
        ScuttleBuddy_SavedVars["location_info"]["eyevea_base_0"] = nil
    end
    purge_duplicate_data()

    InitializePins()
    ScuttleBuddy.update_active_locations()

    --SLASH_COMMANDS["/ssreset"] = function() reset_zone_data() end

    --SLASH_COMMANDS["/ssbuild"] = function() build_zone_data() end

    --SLASH_COMMANDS["/ssbuildall"] = function() build_all_zone_data() end

    SLASH_COMMANDS["/ssrefresh"] = function() ScuttleBuddy.update_antiquity_locations() end

	EVENT_MANAGER:UnregisterForEvent(ScuttleBuddy.addon_name, EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent(ScuttleBuddy.addon_name, EVENT_ADD_ON_LOADED, OnLoad)
