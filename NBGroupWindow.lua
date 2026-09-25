NBPartyFrames = NBPartyFrames or {}

local PARTY_MEMBER_COUNT = 5
local PARTY_MEMBER_DEFAULTS = {
	attached = false,
	orientation = "VERTICAL",
	spacing = 6,
	attachedX = false,
	attachedY = false,
	member1X = false, member1Y = false,
	member2X = false, member2Y = false,
	member3X = false, member3Y = false,
	member4X = false, member4Y = false,
	member5X = false, member5Y = false,
}

local PREVIEW_WIDTH, PREVIEW_HEIGHT = 120, 49
local PREVIEW_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "DRUID" }
local PREVIEW_CLASS_ATLASES = {
	"t-ClassIcon-Warrior",
	"t-ClassIcon-Priest",
	"t-ClassIcon-Mage",
	"t-ClassIcon-Hunter",
	"t-ClassIcon-Druid",
}
local PREVIEW_HEALTH = { 1, 0.78, 0.55, 0.9, 0.32 }
local PREVIEW_POWER = { 0.65, 0.82, 0.48, 0.73, 0.58 }
local MENU_WIDTH = 190
local MENU_ROW_HEIGHT = 22

local anchors = {}
local activeAttachedDrag
local repositioning
local pendingApply
local pendingRevert
local previewButton
local attachCheckbox
local orientationButtons
local spacingLabel, spacingSlider
local menu, menuCatcher

local function ApplyDefaults(destination, source)
	if type(destination) ~= "table" then
		destination = {}
	end
	for key, value in pairs(source) do
		if destination[key] == nil then
			destination[key] = value
		end
	end
	return destination
end

function NBPartyFrames.ApplyGroupWindowDefaults()
	NBPartyFramesDB.groupWindow = ApplyDefaults(NBPartyFramesDB.groupWindow, PARTY_MEMBER_DEFAULTS)
end

local function PartyMemberFrame(index)
	return PartyFrame["MemberFrame" .. index]
end

local function IsAttached()
	return NBPartyFramesDB.groupWindow.attached
end

local function PreviewSize()
	return PREVIEW_WIDTH, PREVIEW_HEIGHT
end

local function ToUIParentUnits(frame, x, y)
	local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * ratio, y * ratio
end

local function ScaledOffset(frame, x, y)
	local frameScale = frame:GetEffectiveScale()
	if not frameScale or frameScale == 0 then
		return x, y
	end
	local ratio = UIParent:GetEffectiveScale() / frameScale
	return x * ratio, y * ratio
end

local function DefaultAnchorOffset(index)
	local _, height = PreviewSize()
	return 20, -220 - (index - 1) * (height * NBPartyFrames.GetPartyFrameScale() + 6)
end

local function StartingAnchorOffset(index)
	local frame = PartyMemberFrame(index)
	if frame then
		local left, top = frame:GetLeft(), frame:GetTop()
		if left and top then
			left, top = ToUIParentUnits(frame, left, top)
			return left - UIParent:GetLeft(), top - UIParent:GetTop()
		end
	end
	return DefaultAnchorOffset(index)
end

local function AttachedPositions(frameGetter)
	local db = NBPartyFramesDB.groupWindow
	local positions = {}
	local x = db.attachedX
	local y = db.attachedY
	if not x or not y then
		x = db.member1X
		y = db.member1Y
	end
	if not x or not y then
		x, y = StartingAnchorOffset(1)
	end
	positions[1] = { x = x, y = y }

	for index = 2, PARTY_MEMBER_COUNT do
		local previous = frameGetter(index - 1)
		local width, height = PreviewSize()
		if previous then
			width = previous:GetWidth() or width
			height = previous:GetHeight() or height
			width, height = ToUIParentUnits(previous, width, height)
		else
			local scale = NBPartyFrames.GetPartyFrameScale()
			width, height = width * scale, height * scale
		end

		if db.orientation == "HORIZONTAL" then
			x = x + width + db.spacing
		else
			y = y - height - db.spacing
		end
		positions[index] = { x = x, y = y }
	end
	return positions
end

local function CloseMenu()
	if menu then
		menu:Hide()
	end
end

local function PositionAnchor(index, anchor, attachedPositions)
	local position = attachedPositions and attachedPositions[index]
	local x = position and position.x or NBPartyFramesDB.groupWindow["member" .. index .. "X"]
	local y = position and position.y or NBPartyFramesDB.groupWindow["member" .. index .. "Y"]
	if not x or not y then
		x, y = StartingAnchorOffset(index)
	end
	local scaledX, scaledY = ScaledOffset(anchor, x, y)
	anchor:ClearAllPoints()
	anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", scaledX, scaledY)
end

local function UpdatePreviewButton()
	if previewButton then
		previewButton:SetText(anchors[1] and anchors[1]:IsShown() and "Hide Preview" or "Preview")
	end
end

local function HidePreview()
	CloseMenu()
	for _, anchor in pairs(anchors) do
		anchor:Hide()
	end
	UpdatePreviewButton()
end

local function SaveAnchorPosition(index, anchor)
	local left, top = anchor:GetLeft(), anchor:GetTop()
	if not left or not top then
		return
	end
	left, top = ToUIParentUnits(anchor, left, top)
	local db = NBPartyFramesDB.groupWindow
	left = left - UIParent:GetLeft()
	top = top - UIParent:GetTop()
	if IsAttached() then
		local positions = AttachedPositions(function(memberIndex)
			return anchors[memberIndex]
		end)
		local first = positions[1]
		local current = positions[index]
		db.attachedX = left - (current.x - first.x)
		db.attachedY = top - (current.y - first.y)
	else
		db["member" .. index .. "X"] = left
		db["member" .. index .. "Y"] = top
	end
	NBPartyFrames.ApplyPartyMemberFramePositions()
	NBPartyFrames.ApplyPartyFramePreview()
end

local function AnchorPositionInUIParent(anchor)
	local left, top = anchor:GetLeft(), anchor:GetTop()
	if not left or not top then
		return
	end
	left, top = ToUIParentUnits(anchor, left, top)
	return left - UIParent:GetLeft(), top - UIParent:GetTop()
end

local function UpdateAttachedDrag(anchor)
	local drag = activeAttachedDrag
	if not drag or drag.anchor ~= anchor then
		return
	end
	local x, y = AnchorPositionInUIParent(anchor)
	if not x or not y then
		return
	end
	local deltaX = x - drag.startX
	local deltaY = y - drag.startY
	for memberIndex, position in pairs(drag.positions) do
		if memberIndex ~= drag.index then
			local memberAnchor = anchors[memberIndex]
			if memberAnchor then
				local scaledX, scaledY = ScaledOffset(
					memberAnchor,
					position.x + deltaX,
					position.y + deltaY
				)
				memberAnchor:ClearAllPoints()
				memberAnchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", scaledX, scaledY)
			end
		end
	end
end

local function BeginAttachedDrag(index, anchor)
	if not IsAttached() then
		return
	end
	local positions = {}
	for memberIndex = 1, PARTY_MEMBER_COUNT do
		local memberAnchor = anchors[memberIndex]
		if memberAnchor then
			local x, y = AnchorPositionInUIParent(memberAnchor)
			if x and y then
				positions[memberIndex] = { x = x, y = y }
			end
		end
	end
	local start = positions[index]
	if not start then
		return
	end
	activeAttachedDrag = {
		anchor = anchor,
		index = index,
		startX = start.x,
		startY = start.y,
		positions = positions,
	}
	anchor:SetScript("OnUpdate", UpdateAttachedDrag)
end

local OpenMenu

local function CreateAnchor(index)
	if anchors[index] then
		return anchors[index]
	end

	local anchor = CreateFrame("Frame", "NBPartyFramesPartyMemberAnchor" .. index, UIParent)
	anchor:SetMovable(true)
	anchor:EnableMouse(true)
	anchor:SetClampedToScreen(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetFrameStrata("DIALOG")

	local portrait = anchor:CreateTexture(nil, "ARTWORK")
	portrait:SetPoint("TOPLEFT", 6, -8)
	portrait:SetSize(30, 30)
	portrait:SetAtlas(PREVIEW_CLASS_ATLASES[index], false)

	local healthBackground = anchor:CreateTexture(nil, "BACKGROUND")
	healthBackground:SetPoint("TOPLEFT", 41, -17)
	healthBackground:SetSize(74, 11)
	healthBackground:SetColorTexture(0, 0, 0, 0.9)

	local healthBar = anchor:CreateTexture(nil, "ARTWORK")
	healthBar:SetPoint("TOPLEFT", healthBackground)
	healthBar:SetSize(74 * PREVIEW_HEALTH[index], 11)
	local r, g, b = NBPartyFrames.GetClassColorRGB(PREVIEW_CLASSES[index])
	healthBar:SetColorTexture(r or 0.1, g or 0.85, b or 0.1, 1)

	local powerBackground = anchor:CreateTexture(nil, "BACKGROUND")
	powerBackground:SetPoint("TOPLEFT", 41, -31)
	powerBackground:SetSize(74, 7)
	powerBackground:SetColorTexture(0, 0, 0, 0.9)

	local powerBar = anchor:CreateTexture(nil, "ARTWORK")
	powerBar:SetPoint("TOPLEFT", powerBackground)
	powerBar:SetSize(74 * PREVIEW_POWER[index], 7)
	powerBar:SetColorTexture(0, 0.45, 1, 1)

	local previewTexture = anchor:CreateTexture(nil, "OVERLAY")
	previewTexture:SetAllPoints()
	previewTexture:SetTexture("Interface\\HUD\\UIPartyFrameC60")
	previewTexture:SetTexCoord(0.0078125, 0.9453125, 0.4140625, 0.796875)

	local name = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("TOPLEFT", 41, -4)
	name:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -5, -4)
	name:SetJustifyH("LEFT")
	name:SetText("Party #" .. index)

	anchor:SetScript("OnDragStart", function(self)
		CloseMenu()
		BeginAttachedDrag(index, self)
		self:StartMoving()
	end)
	anchor:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		UpdateAttachedDrag(self)
		self:SetScript("OnUpdate", nil)
		activeAttachedDrag = nil
		SaveAnchorPosition(index, self)
	end)
	anchor:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			OpenMenu()
		end
	end)
	anchor:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Party member " .. index)
		if IsAttached() then
			GameTooltip:AddLine("Drag: move group", 1, 1, 1)
		else
			GameTooltip:AddLine("Drag: move", 1, 1, 1)
		end
		GameTooltip:AddLine("Right-click: menu", 1, 1, 1)
		GameTooltip:Show()
	end)
	anchor:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	anchor:Hide()
	anchors[index] = anchor
	return anchor
end

local function RefreshAnchor(index, anchor)
	local width, height = PreviewSize()
	anchor:SetSize(width, height)
	anchor:SetScale(NBPartyFrames.GetPartyFrameScale())
end

function NBPartyFrames.ApplyPartyFramePreview()
	for index = 1, PARTY_MEMBER_COUNT do
		if anchors[index] then
			RefreshAnchor(index, anchors[index])
		end
	end
	local positions = IsAttached() and AttachedPositions(function(index)
		return anchors[index]
	end)
	for index = 1, PARTY_MEMBER_COUNT do
		if anchors[index] then
			PositionAnchor(index, anchors[index], positions)
		end
	end
end

local function ShowPreview()
	for index = 1, PARTY_MEMBER_COUNT do
		local anchor = CreateAnchor(index)
		anchor:Show()
	end
	NBPartyFrames.ApplyPartyFramePreview()
	UpdatePreviewButton()
end

local function TogglePreview()
	if anchors[1] and anchors[1]:IsShown() then
		HidePreview()
	else
		ShowPreview()
	end
end

local menuScaleLabel, menuScaleSlider, menuHideButton
local menuRefreshing

local function RefreshMenu()
	local scale = NBPartyFrames.GetPartyFrameScale()
	menuRefreshing = true
	menuScaleSlider:SetValue(scale)
	menuRefreshing = nil
	menuScaleLabel:SetText("Scale: " .. math.floor(scale * 100 + 0.5) .. "%")
	menuHideButton.label:SetText(NBPartyFramesDB.partyFramesHidden and "Show Party Frames" or "Hide Party Frames")
end

local function CreateMenuButton(parent, yOffset, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(MENU_WIDTH - 16, MENU_ROW_HEIGHT)
	button:SetPoint("TOPLEFT", 8, yOffset)
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.label:SetPoint("LEFT", 6, 0)
	button:SetScript("OnClick", function()
		onClick()
		CloseMenu()
	end)
	return button
end

local function BuildMenu()
	menuCatcher = CreateFrame("Button", nil, UIParent)
	menuCatcher:SetAllPoints(UIParent)
	menuCatcher:SetFrameStrata("FULLSCREEN")
	menuCatcher:RegisterForClicks("AnyDown")
	menuCatcher:SetScript("OnClick", CloseMenu)
	menuCatcher:Hide()

	menu = CreateFrame("Frame", "NBPartyFramesPartyMenu", UIParent, "BackdropTemplate")
	menu:SetSize(MENU_WIDTH, 78)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:EnableMouse(true)
	menu:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	menu:SetBackdropColor(0, 0, 0, 0.9)
	menu:Hide()
	menu:SetScript("OnShow", function()
		menuCatcher:Show()
	end)
	menu:SetScript("OnHide", function()
		menuCatcher:Hide()
	end)
	table.insert(UISpecialFrames, "NBPartyFramesPartyMenu")

	menuScaleLabel = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	menuScaleLabel:SetPoint("TOPLEFT", 14, -10)

	menuScaleSlider = CreateFrame("Slider", nil, menu)
	menuScaleSlider:SetPoint("TOPLEFT", 14, -28)
	menuScaleSlider:SetSize(MENU_WIDTH - 28, 16)
	menuScaleSlider:SetMinMaxValues(0.5, 1.5)
	menuScaleSlider:SetValueStep(0.05)
	menuScaleSlider:SetObeyStepOnDrag(true)
	menuScaleSlider:SetOrientation("HORIZONTAL")
	menuScaleSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
	local sliderBackground = menuScaleSlider:CreateTexture(nil, "BACKGROUND")
	sliderBackground:SetAllPoints()
	sliderBackground:SetTexture("Interface/Buttons/UI-SliderBar-Background")
	menuScaleSlider:SetScript("OnValueChanged", function(self, value)
		if menuRefreshing then
			return
		end
		value = math.floor(value * 20 + 0.5) / 20
		NBPartyFramesDB.partyFrameScale = value
		menuScaleLabel:SetText("Scale: " .. math.floor(value * 100 + 0.5) .. "%")
		NBPartyFrames.ApplyPartyFrameScale()
		if NBPartyFrames.RefreshPartyFrameSettings then
			NBPartyFrames.RefreshPartyFrameSettings()
		end
	end)

	menuHideButton = CreateMenuButton(menu, -48, function()
		NBPartyFramesDB.partyFramesHidden = not NBPartyFramesDB.partyFramesHidden
		NBPartyFrames.ApplyPartyFrameVisibility()
	end)
end

OpenMenu = function()
	if not menu then
		BuildMenu()
	end
	RefreshMenu()
	local x, y = GetCursorPosition()
	local uiScale = UIParent:GetEffectiveScale()
	menu:SetScale(1)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / uiScale, y / uiScale)
	menu:Show()
end

local function RepositionAnchorsSoon()
	C_Timer.After(0.1, function()
		if anchors[1] and anchors[1]:IsShown() then
			NBPartyFrames.ApplyPartyFramePreview()
		end
	end)
end

function NBPartyFrames.ApplyPartyMemberFramePositions()
	if InCombatLockdown() then
		pendingApply = true
		return
	end

	pendingApply = nil
	local positions = IsAttached() and AttachedPositions(PartyMemberFrame)
	repositioning = true
	for index = 1, PARTY_MEMBER_COUNT do
		local frame = PartyMemberFrame(index)
		local position = positions and positions[index]
		local x = position and position.x or NBPartyFramesDB.groupWindow["member" .. index .. "X"]
		local y = position and position.y or NBPartyFramesDB.groupWindow["member" .. index .. "Y"]
		if frame and x and x ~= false and y and y ~= false then
			local scaledX, scaledY = ScaledOffset(frame, x, y)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", scaledX, scaledY)
		end
	end
	repositioning = nil
end

local function HookPartyMemberFrames()
	for index = 1, PARTY_MEMBER_COUNT do
		local frame = PartyMemberFrame(index)
		if frame and not frame.NBPartyFramesPositionHooked then
			local pending
			hooksecurefunc(frame, "SetPoint", function()
				if repositioning or pending then
					return
				end
				local x = NBPartyFramesDB.groupWindow["member" .. index .. "X"]
				local y = NBPartyFramesDB.groupWindow["member" .. index .. "Y"]
				if IsAttached() or (x and x ~= false and y and y ~= false) then
					pending = true
					C_Timer.After(0, function()
						pending = nil
						NBPartyFrames.ApplyPartyMemberFramePositions()
					end)
				end
			end)
			frame.NBPartyFramesPositionHooked = true
		end
	end
end

local function RevertPartyMemberLayout()
	if InCombatLockdown() then
		pendingRevert = true
		return
	end
	pendingRevert = nil
	repositioning = true
	for index = 1, PARTY_MEMBER_COUNT do
		local frame = PartyMemberFrame(index)
		if frame then
			frame:ClearAllPoints()
		end
	end
	repositioning = nil
	if PartyFrame:IsShown() then
		PartyFrame:Hide()
		PartyFrame:Show()
	end
end

local function ResetPositions()
	for index = 1, PARTY_MEMBER_COUNT do
		NBPartyFramesDB.groupWindow["member" .. index .. "X"] = false
		NBPartyFramesDB.groupWindow["member" .. index .. "Y"] = false
	end
	NBPartyFramesDB.groupWindow.attachedX = false
	NBPartyFramesDB.groupWindow.attachedY = false
	RevertPartyMemberLayout()
	RepositionAnchorsSoon()
end

local function ApplyEditMode()
	if NBPartyFramesDB.editMode then
		ShowPreview()
	else
		HidePreview()
	end
end

local function ApplyAttachedLayout()
	NBPartyFrames.ApplyPartyFramePreview()
	NBPartyFrames.ApplyPartyMemberFramePositions()
end

local function RefreshLayoutControls()
	if not attachCheckbox then
		return
	end
	local db = NBPartyFramesDB.groupWindow
	local enabled = db.attached
	attachCheckbox:SetChecked(enabled)
	for orientation, button in pairs(orientationButtons) do
		button:SetText(orientation == "HORIZONTAL" and "Horizontal" or "Vertical")
		if orientation == db.orientation then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
		if enabled then
			button:Enable()
		else
			button:Disable()
		end
		button:SetAlpha(enabled and 1 or 0.5)
	end
	if enabled then
		spacingSlider:Enable()
	else
		spacingSlider:Disable()
	end
	spacingSlider:SetAlpha(enabled and 1 or 0.5)
	spacingLabel:SetAlpha(enabled and 1 or 0.5)
	spacingSlider:SetValue(db.spacing)
	spacingLabel:SetText("Spacing: " .. db.spacing .. " px")
end

NBPartyFrames.RefreshGroupWindowSettings = RefreshLayoutControls

function NBPartyFrames.BuildGroupWindowSettings(parent, yOffset)
	attachCheckbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	attachCheckbox:SetPoint("TOPLEFT", 16, yOffset)
	attachCheckbox.Text:SetText("Attach frames")
	attachCheckbox:SetChecked(NBPartyFramesDB.groupWindow.attached)
	attachCheckbox:SetScript("OnClick", function(self)
		local db = NBPartyFramesDB.groupWindow
		db.attached = self:GetChecked() and true or false
		RefreshLayoutControls()
		ApplyAttachedLayout()
	end)

	local orientationLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	orientationLabel:SetPoint("TOPLEFT", 190, yOffset - 4)
	orientationLabel:SetText("Orientation")

	orientationButtons = {}
	for buttonIndex, orientation in ipairs({ "HORIZONTAL", "VERTICAL" }) do
		local selectedOrientation = orientation
		local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		button:SetSize(92, 22)
		if buttonIndex == 1 then
			button:SetPoint("TOPLEFT", 270, yOffset + 2)
		else
			button:SetPoint("LEFT", orientationButtons.HORIZONTAL, "RIGHT", 6, 0)
		end
		button:SetScript("OnClick", function()
			NBPartyFramesDB.groupWindow.orientation = selectedOrientation
			RefreshLayoutControls()
			ApplyAttachedLayout()
		end)
		orientationButtons[orientation] = button
	end
	yOffset = yOffset - 34

	spacingLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	spacingLabel:SetPoint("TOPLEFT", 16, yOffset - 3)

	spacingSlider = CreateFrame("Slider", nil, parent)
	spacingSlider:SetPoint("TOPLEFT", 108, yOffset)
	spacingSlider:SetSize(194, 16)
	spacingSlider:SetMinMaxValues(0, 50)
	spacingSlider:SetValueStep(1)
	spacingSlider:SetObeyStepOnDrag(true)
	spacingSlider:SetOrientation("HORIZONTAL")
	spacingSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
	local spacingBackground = spacingSlider:CreateTexture(nil, "BACKGROUND")
	spacingBackground:SetAllPoints()
	spacingBackground:SetTexture("Interface/Buttons/UI-SliderBar-Background")
	spacingSlider:SetValue(NBPartyFramesDB.groupWindow.spacing)
	spacingSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		if value == NBPartyFramesDB.groupWindow.spacing then
			return
		end
		NBPartyFramesDB.groupWindow.spacing = value
		spacingLabel:SetText("Spacing: " .. value .. " px")
		ApplyAttachedLayout()
	end)
	RefreshLayoutControls()
	previewButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	previewButton:SetSize(96, 22)
	previewButton:SetPoint("TOPLEFT", 324, yOffset + 3)
	previewButton:SetScript("OnClick", TogglePreview)
	UpdatePreviewButton()

	local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	resetButton:SetSize(96, 22)
	resetButton:SetPoint("LEFT", previewButton, "RIGHT", 6, 0)
	resetButton:SetText("Reset")
	resetButton:SetScript("OnClick", ResetPositions)
	yOffset = yOffset - 30

	return yOffset
end

local eventFrame = CreateFrame("Frame", "NBPartyFramesPartyMemberEvents")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName ~= "NBPartyFrames" then
			return
		end
		NBPartyFrames.ApplyGroupWindowDefaults()
		NBPartyFrames.RegisterEditModeHandler(ApplyEditMode)
	elseif event == "PLAYER_LOGIN" then
		HookPartyMemberFrames()
		NBPartyFrames.ApplyPartyMemberFramePositions()
		ApplyEditMode()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingRevert then
			RevertPartyMemberLayout()
		elseif pendingApply then
			NBPartyFrames.ApplyPartyMemberFramePositions()
		end
	elseif event == "GROUP_ROSTER_UPDATE"
		or event == "PLAYER_ENTERING_WORLD"
		or event == "UI_SCALE_CHANGED"
	then
		C_Timer.After(0, function()
			HookPartyMemberFrames()
			NBPartyFrames.ApplyPartyMemberFramePositions()
		end)
	end
end)
