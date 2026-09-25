NBPartyFrames = NBPartyFrames or {}

local FRAME_WIDTH = 568
local SECTION_MARGIN = 16
local SECTION_GAP = 14
local SLIDER_WIDTH = 200
local ICON_UNITFRAMES = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local ICON_GRID = "Interface\\Icons\\INV_Misc_Map_01"
local ICON_PROFILE = "Interface\\Icons\\INV_Misc_Note_06"
local classColorsCheckbox

local function CreateSettingsCheckbox(parent, label, dbKey, xOffset, yOffset, onChange)
	local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", xOffset, yOffset)
	checkbox.Text:SetText(label)
	checkbox:SetChecked(NBPartyFramesDB[dbKey])
	checkbox:SetScript("OnClick", function(self)
		NBPartyFramesDB[dbKey] = self:GetChecked() and true or false
		onChange()
	end)
	return checkbox
end

local function CreateSectionBox(parent, x, topY, width, title, iconTexture)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetWidth(width)
	box:SetPoint("TOPLEFT", x, topY)
	box:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	box:SetBackdropColor(1, 1, 1, 0.03)
	box:SetBackdropBorderColor(1, 1, 1, 0.3)

	local icon = box:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("TOPLEFT", 10, -10)
	icon:SetTexture(iconTexture)

	local header = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("LEFT", icon, "RIGHT", 4, 0)
	header:SetText(title)
	return box
end

local function BuildSettings(box, yOffset)
	classColorsCheckbox = CreateSettingsCheckbox(box, "Class colors", "classColorHealth", 16, yOffset, function()
		NBPartyFrames.ApplyUnitFrameColours()
		NBPartyFrames.ApplyPartyFramePreview()
	end)
	local scaleLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	scaleLabel:SetPoint("TOPLEFT", 286, yOffset - 2)
	local function RefreshScaleLabel()
		scaleLabel:SetText("Party frame scale: " .. math.floor(NBPartyFramesDB.partyFrameScale * 100 + 0.5) .. "%")
	end
	RefreshScaleLabel()

	local scaleSlider = CreateFrame("Slider", nil, box)
	scaleSlider:SetPoint("TOPLEFT", 286, yOffset - 20)
	scaleSlider:SetMinMaxValues(0.5, 1.5)
	scaleSlider:SetValueStep(0.05)
	scaleSlider:SetObeyStepOnDrag(true)
	scaleSlider:SetOrientation("HORIZONTAL")
	scaleSlider:SetSize(SLIDER_WIDTH, 16)
	scaleSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

	local sliderBackground = scaleSlider:CreateTexture(nil, "BACKGROUND")
	sliderBackground:SetAllPoints()
	sliderBackground:SetTexture("Interface/Buttons/UI-SliderBar-Background")

	scaleSlider:SetValue(NBPartyFramesDB.partyFrameScale)
	scaleSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value * 20 + 0.5) / 20
		NBPartyFramesDB.partyFrameScale = value
		RefreshScaleLabel()
		NBPartyFrames.ApplyPartyFrameScale()
	end)
	yOffset = yOffset - 46

	NBPartyFrames.RefreshPartyFrameSettings = function()
		scaleSlider:SetValue(NBPartyFramesDB.partyFrameScale)
		RefreshScaleLabel()
	end

	return NBPartyFrames.BuildGroupWindowSettings(box, yOffset)
end

local function BuildEditModeSettings(box, yOffset)
	local editModeCheckbox = CreateSettingsCheckbox(box, "Edit mode", "editMode", 16, yOffset, function()
		NBPartyFrames.SetEditMode(NBPartyFramesDB.editMode)
	end)

	local gridCheckbox = CreateSettingsCheckbox(box, "Show grid", "showGrid", 180, yOffset, function()
		NBPartyFrames.SetGridVisible(NBPartyFramesDB.showGrid)
	end)
	yOffset = yOffset - 34

	NBPartyFrames.RefreshEditModeSettings = function()
		editModeCheckbox:SetChecked(NBPartyFramesDB.editMode)
		gridCheckbox:SetChecked(NBPartyFramesDB.showGrid)
	end

	return NBPartyFrames.BuildGridSettings(box, yOffset)
end

local function BuildProfileSettings(box, yOffset)
	local activeLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	activeLabel:SetPoint("TOPLEFT", 10, yOffset)

	local statusText = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	statusText:SetWidth(box:GetWidth() - 20)
	statusText:SetJustifyH("LEFT")

	local selectedProfile = NBPartyFrames.GetActiveProfile()
	local profileDropdown
	local nameBox

	local function RefreshSummary()
		local active = NBPartyFrames.GetActiveProfile()
		activeLabel:SetText("Active: " .. (active or "Character-specific"))

		local available = {}
		for _, name in ipairs(NBPartyFrames.GetProfileNames()) do
			available[name] = true
		end
		if active and available[active] then
			selectedProfile = active
		elseif selectedProfile and not available[selectedProfile] then
			selectedProfile = nil
		end
		profileDropdown:SetText(selectedProfile or "Select profile")
		profileDropdown:GenerateMenu()
	end

	local function ShowStatus(success, message)
		statusText:SetTextColor(success and 0.3 or 1, success and 1 or 0.3, 0.3)
		statusText:SetText(message or "")
		RefreshSummary()
	end

	yOffset = yOffset - 28
	local dropdownLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	dropdownLabel:SetPoint("TOPLEFT", 10, yOffset)
	dropdownLabel:SetText("Select a saved profile")

	local nameLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameLabel:SetPoint("TOPLEFT", 300, yOffset)
	nameLabel:SetText("Profile name")
	yOffset = yOffset - 18

	profileDropdown = CreateFrame("DropdownButton", nil, box, "WowStyle1DropdownTemplate")
	profileDropdown:SetSize(270, 26)
	profileDropdown:SetPoint("TOPLEFT", 10, yOffset)

	nameBox = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
	nameBox:SetSize(216, 20)
	nameBox:SetPoint("TOPLEFT", 310, yOffset + 3)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(32)
	nameBox:SetText(selectedProfile or "")
	yOffset = yOffset - 34

	local saveButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	saveButton:SetSize(84, 22)
	saveButton:SetPoint("TOPLEFT", 10, yOffset + 5)
	saveButton:SetText("Save")

	local loadButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	loadButton:SetSize(84, 22)
	loadButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)
	loadButton:SetText("Load")

	local deleteButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	deleteButton:SetSize(84, 22)
	deleteButton:SetPoint("LEFT", loadButton, "RIGHT", 6, 0)
	deleteButton:SetText("Delete")
	yOffset = yOffset - 32

	statusText:SetPoint("TOPLEFT", 10, yOffset)

	local function SelectProfile(name)
		selectedProfile = name
		nameBox:SetText(name)
		profileDropdown:SetText(name)
	end

	profileDropdown:SetupMenu(function(_, rootDescription)
		local names = NBPartyFrames.GetProfileNames()
		if #names == 0 then
			rootDescription:CreateTitle("No profiles saved")
			return
		end

		for _, name in ipairs(names) do
			rootDescription:CreateRadio(name, function(value)
				return value == selectedProfile
			end, function(value)
				SelectProfile(value)
			end, name)
		end
	end)

	saveButton:SetScript("OnClick", function()
		local success, message = NBPartyFrames.SaveProfile(nameBox:GetText())
		if success then
			selectedProfile = NBPartyFrames.GetActiveProfile()
		end
		ShowStatus(success, message)
	end)
	nameBox:SetScript("OnEnterPressed", function(self)
		local success, message = NBPartyFrames.SaveProfile(self:GetText())
		if success then
			selectedProfile = NBPartyFrames.GetActiveProfile()
		end
		self:ClearFocus()
		ShowStatus(success, message)
	end)
	nameBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	loadButton:SetScript("OnClick", function()
		local success, message = NBPartyFrames.LoadProfile(nameBox:GetText())
		ShowStatus(success, message)
	end)
	deleteButton:SetScript("OnClick", function()
		local success, message = NBPartyFrames.DeleteProfile(nameBox:GetText())
		if success then
			selectedProfile = nil
			nameBox:SetText("")
		end
		ShowStatus(success, message)
	end)

	RefreshSummary()
	box.RefreshProfiles = RefreshSummary
	return yOffset - 32
end

local function CreateSettingsPanel()
	local panel = CreateFrame("Frame", "NBPartyFramesSettingsPanel")
	panel.name = "NBPartyFrames"
	panel.OnCommit = function() end
	panel.OnDefault = function() end
	panel.OnRefresh = function() end

	local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 4)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(FRAME_WIDTH)
	scrollFrame:SetScrollChild(content)

	local heading = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", SECTION_MARGIN, -12)
	heading:SetText("NBPartyFrames")

	local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
	description:SetWidth(FRAME_WIDTH - SECTION_MARGIN * 2)
	description:SetJustifyH("LEFT")
	description:SetText("Class colors, scaling, layout, and edit mode for Blizzard party frames.")

	local topY = -62
	local width = FRAME_WIDTH - SECTION_MARGIN * 2
	local unitFrameBox = CreateSectionBox(content, SECTION_MARGIN, topY, width, "Unit Frames", ICON_UNITFRAMES)
	local unitFrameEndY = BuildSettings(unitFrameBox, -30)
	unitFrameBox:SetHeight(-unitFrameEndY + 10)

	local editModeTopY = topY - unitFrameBox:GetHeight() - SECTION_GAP
	local editModeBox = CreateSectionBox(content, SECTION_MARGIN, editModeTopY, width, "Edit Mode", ICON_GRID)
	local editModeEndY = BuildEditModeSettings(editModeBox, -30)
	editModeBox:SetHeight(-editModeEndY + 10)

	local profilesTopY = editModeTopY - editModeBox:GetHeight() - SECTION_GAP
	local profilesBox = CreateSectionBox(content, SECTION_MARGIN, profilesTopY, width, "Profiles", ICON_PROFILE)
	local profilesEndY = BuildProfileSettings(profilesBox, -30)
	profilesBox:SetHeight(-profilesEndY + 10)
	content:SetHeight(-profilesTopY + profilesBox:GetHeight() + 20)

	function NBPartyFrames.RefreshSettingsPanels()
		classColorsCheckbox:SetChecked(NBPartyFramesDB.classColorHealth)
		NBPartyFrames.RefreshPartyFrameSettings()
		NBPartyFrames.RefreshGroupWindowSettings()
		NBPartyFrames.RefreshEditModeSettings()
		NBPartyFrames.RefreshGridSettings()
		profilesBox.RefreshProfiles()
	end

	panel:SetScript("OnShow", NBPartyFrames.RefreshSettingsPanels)
	return panel
end

local settingsCategory
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
	local panel = CreateSettingsPanel()
	settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "NBPartyFrames")
	Settings.RegisterAddOnCategory(settingsCategory)
	self:UnregisterEvent("PLAYER_LOGIN")
end)

local function OpenSettings()
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00NBPartyFrames:|r Options cannot be opened during combat.")
		return
	end
	if settingsCategory then
		Settings.OpenToCategory(settingsCategory:GetID())
	end
end

SLASH_NBPARTYFRAMES1 = "/nbpartyframes"
SLASH_NBPARTYFRAMES2 = "/nbpf"
SlashCmdList["NBPARTYFRAMES"] = function(msg)
	msg = strtrim(string.lower(msg or ""))
	if msg == "edit" then
		NBPartyFrames.SetEditMode(not NBPartyFramesDB.editMode)
		return
	end
	if msg == "grid" then
		NBPartyFrames.SetGridVisible(not NBPartyFramesDB.showGrid)
		return
	end
	OpenSettings()
end
