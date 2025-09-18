local AutoUpdater = {
    name = "Miniature Movement Injector",
    version = "2.1.0",
    versionUrl = "https://raw.githubusercontent.com/cornernote/tabletop_simulator-miniature_movement_injector/refs/heads/main/lua/miniature-movement-injector.ver",
    scriptUrl = "https://raw.githubusercontent.com/cornernote/tabletop_simulator-miniature_movement_injector/refs/heads/main/lua/miniature-movement-injector.lua",
    debug = false,

    run = function(self, host)
        self.host = host
        if not self.host then
            self:error("Error: host not set, ensure AutoUpdater:run(self) is in your onLoad() function")
            return
        end
        self:checkForUpdate()
        self:updateAssets()
    end,
    checkForUpdate = function(self)
        WebRequest.get(self.versionUrl, function(request)
            if request.response_code ~= 200 then
                self:error("Failed to check version (" .. request.response_code .. ": " .. request.error .. ")")
                return
            end
            local remoteVersion = request.text:match("[^\r\n]+") or ""
            if self:isNewerVersion(remoteVersion) then
                self:fetchNewScript(remoteVersion)
            end
        end)
    end,
    isNewerVersion = function(self, remoteVersion)
        local function split(v)
            return { v:match("^(%d+)%.?(%d*)%.?(%d*)") or 0 }
        end
        local r, l = split(remoteVersion), split(self.version)
        for i = 1, math.max(#r, #l) do
            local rv, lv = tonumber(r[i]) or 0, tonumber(l[i]) or 0
            if rv ~= lv then
                return rv > lv
            end
        end
        return false
    end,
    fetchNewScript = function(self, newVersion)
        WebRequest.get(self.scriptUrl, function(request)
            if request.response_code ~= 200 then
                self:error("Failed to fetch new script (" .. request.response_code .. ": " .. request.error .. ")")
                return
            end
            if request.text and #request.text > 0 then
                self.host.setLuaScript(request.text)
                self:print("Updated to version " .. newVersion)
                self:reload()
            else
                self:error("New script is empty")
            end
        end)
    end,
    print = function(self, message)
        print(self.name .. ": " .. message)
    end,
    error = function(self, message)
        if self.debug then
            error(self.name .. ": " .. message)
        end
    end,
    reload = function(self)
        Wait.condition(function()
            return not self.host or self.host.reload()
        end, function()
            return not self.host or self.host.resting
        end)
    end,
    updateAssets = function(self)
        local correctTop = "https://steamusercontent-a.akamaihd.net/ugc/16348925285980654885/BF24BD143E9939702D8AB855D231B2A3A30520B1/"
        local correctBottom = "https://steamusercontent-a.akamaihd.net/ugc/14530667653373661105/0A203F20E29B006A85C3763B05F16D3DBC1EF8B7/"

        local data = self.host.getCustomObject()
        local needsAssetUpdate = false

        if not data.image or data.image ~= correctTop then
            data.image = correctTop
            needsAssetUpdate = true
        end
        if not data.image_secondary or data.image_secondary ~= correctBottom then
            data.image_secondary = correctBottom
            needsAssetUpdate = true
        end

        if needsAssetUpdate then
            self:print("Updated assets")
            self.host.setCustomObject(data)
            self:reload()
        end
    end
}

local SCRIPT_TO_INJECT_TEMPLATE = [[
--[miniature-movement-injector]--

-- Miniature Movement Injector by CoRNeRNoTe
-- Most recent script can be found on GitHub:
-- https://github.com/cornernote/tabletop_simulator-miniature_movement_injector/blob/main/lua/miniature-movement.lua

function onPickUp(color)
    local gridX = Grid and Grid.sizeX or 2
    local startPos = self.getPosition()

    for _, hit in ipairs(Physics.cast({
        origin = self.getBoundsNormalized().center - self.getBoundsNormalized().size,
        direction = {0, -1, 0},
        type = 1,
        max_distance = 10
    })) do
        if hit.point and hit.hit_object ~= self then
            startPos = hit.point
            break
        end
    end
	
	startPos[2] = startPos[2] + 0.01

    local spinner = spawnObject({
        type = "Custom_Model",
        position = startPos,
        rotation = {0, 0, 0},
        scale = {gridX / 2.2, 0.1, gridX / 2.2}
    })

    spinner.setLock(true)
    spinner.setCustomObject({
        type = "coin",
        mesh = "https://steamusercontent-a.akamaihd.net/ugc/16857831131281253981/0E81BD50654AB5A5AEE29ABB24495CF15C717E1D/",
    })
	spinner.setColorTint({1, 1, 1})
    spinner.interactable = false
    spinner.lock()

    spinner.createButton({
        click_function = "noop",
        function_owner = self,
        label = "0",
        position = {0, 0, 0},
		font_color = color,
        width = 0,
		height = 0,
        font_size = 400
    })

	self.clearButtons()
    self.createButton({
        click_function = "noop",
        function_owner = self,
        label = "0",
        position = {0, self.getVisualBoundsNormalized().size.z + 1, 0},
		font_color = {1, 1, 1},
        width = 0,
		height = 0,
        font_size = 400
    })

    local parentGUID = self.getGUID()
    spinner.setLuaScript([=[
        local time_of_release = nil
        
        function onUpdate()
            local parent = getObjectFromGUID("]=] .. parentGUID .. [=[")
            
            if parent and parent.held_by_color then
			    if (not time_of_release) then
					local gridX = Grid and Grid.sizeX or 2
					local diff = self.getPosition() - parent.getPosition()
					diff.y = 0
					local dist = math.max(math.abs(diff.x), math.abs(diff.z)) * (5.0 / gridX)
					parent.editButton({index=0, label=tostring(math.floor((dist+2.5)/5.0))})
					self.editButton({index=0, label=tostring(math.floor((dist+2.5)/5.0))})
					self.setRotation({0, self.getRotation().y + 1, 0})
                end
            else
                -- The object is NOT being held.
                if time_of_release == nil then
                    time_of_release = os.clock()
                end

                -- Check if time has passed since release.
                if os.clock() - time_of_release >= 5 then
                    destroyObject(self)
                end
            end
        end
    ]=])
end

local time_of_release = nil
function onUpdate()
	if self.held_by_color then
	    time_of_release = nil
    else
		if time_of_release == nil then
			time_of_release = os.clock()
		end

		if os.clock() - time_of_release >= 5 then
			self.clearButtons()
		end
	end
end

function noop() end
]]

function onLoad()
    AutoUpdater:run(self)
end

function onObjectDrop(player_color, dropped_object)
    if self.getGUID() == dropped_object.getGUID() then
        return
    end

    local function getObjectBounds(obj)
        local bounds = obj.getBounds()
        local min_pos = Vector(bounds.center.x - bounds.size.x / 2,
                bounds.center.y - bounds.size.y / 2,
                bounds.center.z - bounds.size.z / 2)
        local max_pos = Vector(bounds.center.x + bounds.size.x / 2,
                bounds.center.y + bounds.size.y / 2,
                bounds.center.z + bounds.size.z / 2)
        return min_pos, max_pos
    end

    local drop_zone_height = 5

    local panel_min_pos, panel_max_pos = getObjectBounds(self)
    local dropped_obj_min_pos, dropped_obj_max_pos = getObjectBounds(dropped_object)

    panel_max_pos.y = panel_max_pos.y + drop_zone_height

    if (dropped_obj_min_pos.x < panel_max_pos.x and dropped_obj_max_pos.x > panel_min_pos.x) and
            (dropped_obj_min_pos.y < panel_max_pos.y and dropped_obj_max_pos.y > panel_min_pos.y) and
            (dropped_obj_min_pos.z < panel_max_pos.z and dropped_obj_max_pos.z > panel_min_pos.z) then

        local rotation = self.getRotation()
        local panel_orientation = "right way up"
        if math.abs(rotation.x) > 170 or math.abs(rotation.z) > 170 then
            panel_orientation = "upside down"
        end

        local valid_tags = { "Miniature", "Figurine", "Figure", "Model", "Tile" }
        local is_miniature = false
        for _, tag in ipairs(valid_tags) do
            if dropped_object.tag == tag then
                is_miniature = true
                break
            end
        end

        if is_miniature then
            if panel_orientation == "right way up" then
                local current_script = dropped_object.getLuaScript()

                if current_script == "" or not current_script:find("--[miniature-movement-injector]--", 0, true) then
                    dropped_object.setLuaScript(SCRIPT_TO_INJECT_TEMPLATE)
                    broadcastToAll("Script injected into '" .. dropped_object.getName() .. "'!")
                else
                    broadcastToAll("Script already exists on '" .. dropped_object.getName() .. "'. No changes made.")
                end
            elseif panel_orientation == "upside down" then
                local current_script = dropped_object.getLuaScript()

                if current_script:find("--[miniature-movement-injector]--", 1, true) then
                    dropped_object.script_state = ""
                    dropped_object.script_code = ""
                    dropped_object.setLuaScript("")
                    dropped_object.reload()
                    broadcastToAll("Script removed from '" .. dropped_object.getName() .. "'!")
                else
                    broadcastToAll("No script to remove from '" .. dropped_object.getName() .. "'.")
                end
            end
        else
            print("An object of type '" .. dropped_object.type .. "' was dropped on the panel. No action taken.")
        end
    end
end
