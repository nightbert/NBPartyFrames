NBPartyFrames = NBPartyFrames or {}

local DB_DEFAULTS = {
	classColorHealth = false,
	partyFrameScale = 1.0,
	partyFramesHidden = false,
	editMode = false,
	showGrid = false,
	gridSpacing = 32,
}

function NBPartyFrames.ApplyDatabaseDefaults()
	for key, value in pairs(DB_DEFAULTS) do
		if NBPartyFramesDB[key] == nil then
			NBPartyFramesDB[key] = value
		end
	end
end

function NBPartyFrames.GetClassColorRGB(classToken)
	local color = C_ClassColor.GetClassColor(classToken)
	if color then
		return color:GetRGB()
	end
end

local editModeHandlers = {}

function NBPartyFrames.RegisterEditModeHandler(handler)
	table.insert(editModeHandlers, handler)
end

function NBPartyFrames.ApplyEditMode()
	for _, handler in ipairs(editModeHandlers) do
		handler()
	end
end

function NBPartyFrames.SetEditMode(enabled)
	NBPartyFramesDB.editMode = enabled and true or false
	NBPartyFrames.ApplyEditMode()
	if NBPartyFrames.RefreshEditModeSettings then
		NBPartyFrames.RefreshEditModeSettings()
	end
end

function NBPartyFrames.SetGridVisible(enabled)
	NBPartyFramesDB.showGrid = enabled and true or false
	NBPartyFrames.ApplyGrid()
	if NBPartyFrames.RefreshEditModeSettings then
		NBPartyFrames.RefreshEditModeSettings()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName ~= "NBPartyFrames" then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	if type(NBPartyFramesDB) ~= "table" then
		local backup = type(NBPartyFramesCharDB) == "table" and NBPartyFramesCharDB.db
		NBPartyFramesDB = type(backup) == "table" and backup or {}
	end
	NBPartyFramesCharDB = type(NBPartyFramesCharDB) == "table" and NBPartyFramesCharDB or {}
	if NBPartyFrames.InitializeProfiles then
		NBPartyFrames.InitializeProfiles()
	end
	NBPartyFrames.ApplyDatabaseDefaults()
	NBPartyFramesCharDB.db = NBPartyFramesDB
end)
