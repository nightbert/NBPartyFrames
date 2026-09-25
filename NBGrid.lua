NBPartyFrames = NBPartyFrames or {}

local GRID_MIN_SPACING = 8
local GRID_MAX_SPACING = 128
local GRID_STEP = 4
local LINE_COLOUR = { 1, 1, 1, 0.2 }
local CENTER_COLOUR = { 1, 0.15, 0.15, 0.7 }

local grid = CreateFrame("Frame", "NBPartyFramesGrid", UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("BACKGROUND")
grid:EnableMouse(false)
grid:Hide()

local lines = {}
local usedLines = 0

local function AcquireLine()
	usedLines = usedLines + 1
	local line = lines[usedLines]
	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		lines[usedLines] = line
	end
	line:ClearAllPoints()
	line:Show()
	return line
end

local function DrawLine(vertical, offset, thickness, colour)
	local line = AcquireLine()
	line:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
	if vertical then
		line:SetPoint("TOP", grid, "TOP", offset, 0)
		line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
		line:SetWidth(thickness)
	else
		line:SetPoint("LEFT", grid, "LEFT", 0, offset)
		line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
		line:SetHeight(thickness)
	end
end

local function RebuildGrid()
	local spacing = NBPartyFramesDB.gridSpacing
	local width, height = grid:GetSize()
	if not width or width == 0 or not height or height == 0 then
		return
	end
	local thickness = 1 / UIParent:GetEffectiveScale()

	usedLines = 0
	DrawLine(true, 0, thickness, CENTER_COLOUR)
	DrawLine(false, 0, thickness, CENTER_COLOUR)
	for offset = spacing, width / 2, spacing do
		DrawLine(true, offset, thickness, LINE_COLOUR)
		DrawLine(true, -offset, thickness, LINE_COLOUR)
	end
	for offset = spacing, height / 2, spacing do
		DrawLine(false, offset, thickness, LINE_COLOUR)
		DrawLine(false, -offset, thickness, LINE_COLOUR)
	end
	for index = usedLines + 1, #lines do
		lines[index]:Hide()
	end
end

function NBPartyFrames.ApplyGrid()
	if NBPartyFramesDB.showGrid then
		grid:Show()
		RebuildGrid()
	else
		grid:Hide()
	end
end

function NBPartyFrames.BuildGridSettings(parent, yOffset)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", 14, yOffset - 3)

	local slider = CreateFrame("Slider", nil, parent)
	slider:SetPoint("TOPLEFT", 130, yOffset)
	slider:SetMinMaxValues(GRID_MIN_SPACING, GRID_MAX_SPACING)
	slider:SetValueStep(GRID_STEP)
	slider:SetObeyStepOnDrag(true)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(160, 16)
	slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

	local sliderBackground = slider:CreateTexture(nil, "BACKGROUND")
	sliderBackground:SetAllPoints(true)
	sliderBackground:SetTexture("Interface/Buttons/UI-SliderBar-Background")

	local function UpdateLabel()
		label:SetText("Grid spacing: " .. NBPartyFramesDB.gridSpacing .. " px")
	end

	NBPartyFrames.RefreshGridSettings = function()
		slider:SetValue(NBPartyFramesDB.gridSpacing)
		UpdateLabel()
	end

	slider:SetValue(NBPartyFramesDB.gridSpacing)
	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value / GRID_STEP + 0.5) * GRID_STEP
		if value == NBPartyFramesDB.gridSpacing then
			return
		end
		NBPartyFramesDB.gridSpacing = value
		UpdateLabel()
		if NBPartyFramesDB.showGrid then
			RebuildGrid()
		end
	end)
	UpdateLabel()
	yOffset = yOffset - 26

	return yOffset
end

local eventFrame = CreateFrame("Frame", "NBPartyFramesGridEvents")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName ~= "NBPartyFrames" then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		local spacing = tonumber(NBPartyFramesDB.gridSpacing) or 32
		NBPartyFramesDB.gridSpacing = math.max(GRID_MIN_SPACING, math.min(GRID_MAX_SPACING, spacing))
	elseif NBPartyFramesDB.showGrid then
		C_Timer.After(0, NBPartyFrames.ApplyGrid)
	end
end)
