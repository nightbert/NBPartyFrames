NBPartyFrames = NBPartyFrames or {}

local partyOriginalParent
local pendingPartyScale
local pendingPartyPetVisibility
local pendingPartyVisibility
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

function NBPartyFrames.GetPartyFrameScale()
	return NBPartyFramesDB.partyFrameScale or 1.0
end

function NBPartyFrames.ApplyPartyFrameScale(scale)
	scale = scale or NBPartyFrames.GetPartyFrameScale()
	if InCombatLockdown() then
		pendingPartyScale = scale
		if NBPartyFrames.ApplyPartyFramePreview then
			NBPartyFrames.ApplyPartyFramePreview()
		end
		return
	end
	pendingPartyScale = nil

	PartyFrame:SetScale(scale)
	if NBPartyFrames.ApplyPartyMemberFramePositions then
		NBPartyFrames.ApplyPartyMemberFramePositions()
	end
	if NBPartyFrames.ApplyPartyFramePreview then
		NBPartyFrames.ApplyPartyFramePreview()
	end
end

function NBPartyFrames.ApplyPartyPetVisibility()
	if InCombatLockdown() then
		pendingPartyPetVisibility = true
		return
	end
	pendingPartyPetVisibility = nil

	local show = NBPartyFramesDB.showPartyPets and true or false
	if GetCVarBool("showPartyPets") ~= show then
		SetCVar("showPartyPets", show and "1" or "0")
	end
end

function NBPartyFrames.ApplyPartyFrameVisibility()
	local hide = NBPartyFramesDB.partyFramesHidden and true or false
	PartyFrame:SetAlpha(hide and 0 or 1)
	if InCombatLockdown() then
		pendingPartyVisibility = true
		return
	end
	pendingPartyVisibility = nil

	if hide then
		if PartyFrame:GetParent() ~= hiddenParent then
			partyOriginalParent = partyOriginalParent or PartyFrame:GetParent()
			PartyFrame:SetParent(hiddenParent)
		end
	elseif partyOriginalParent and PartyFrame:GetParent() == hiddenParent then
		PartyFrame:SetParent(partyOriginalParent)
		partyOriginalParent = nil
		if NBPartyFrames.ApplyPartyMemberFramePositions then
			NBPartyFrames.ApplyPartyMemberFramePositions()
		end
	end
end


local green = CreateColor(0, 1, 0)
local grey = CreateColor(0.5, 0.5, 0.5)
local yellow = CreateColor(1, 1, 0)
local red = CreateColor(1, 0, 0)
local paintedBars = {}
local EnsureColourHook
local coloursWereEnabled = false

local identityEvents = {
	"PLAYER_ENTERING_WORLD",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED",
	"GROUP_ROSTER_UPDATE",
	"UI_SCALE_CHANGED",
	"UNIT_TARGET",
	"UNIT_PET",
	"UNIT_ENTERED_VEHICLE",
	"UNIT_EXITED_VEHICLE",
}

local function ClassColoursEnabled()
	return NBPartyFramesDB and NBPartyFramesDB.classColorHealth
end


local function GetPlayerUnitColour(unit)
	local _, classToken = UnitClass(unit)
	if type(classToken) ~= "string" then
		return green, false
	end

	local colour = C_ClassColor.GetClassColor(classToken)
	return colour or green, colour ~= nil
end

local function GetNpcUnitColour(unit)
	if UnitIsTapDenied(unit) then
		return grey, false
	end

	local reaction = UnitReaction("player", unit)
	if not reaction then
		return yellow, false
	elseif reaction >= 5 then
		return green, false
	elseif reaction == 4 then
		return yellow, false
	end
	return red, false
end

local function GetUnitColour(unit)
	if UnitIsPlayer(unit) or unit == "pet" then
		return GetPlayerUnitColour(unit == "pet" and "player" or unit)
	end
	return GetNpcUnitColour(unit)
end

local function GetDefaultUnitColour(unit)
	if UnitExists(unit) and not UnitIsConnected(unit) then
		return grey
	end
	if UnitIsPlayer(unit) or unit == "pet" then
		return green
	end
	return GetNpcUnitColour(unit)
end

local function PaintHealthBar(healthBar, unit, useClassColours)
	if not healthBar or not unit then
		return
	end

	local colour
	if useClassColours then
		colour = GetUnitColour(unit)
	else
		colour = GetDefaultUnitColour(unit)
	end

	healthBar.NBPartyFramesColourApplying = true
	local texture = healthBar:GetStatusBarTexture()
	if texture and texture.SetDesaturated then
		texture:SetDesaturated(useClassColours and true or false)
	end
	healthBar:SetStatusBarColor(colour.r, colour.g, colour.b)
	healthBar.NBPartyFramesColourApplying = false
	EnsureColourHook(healthBar)
end

EnsureColourHook = function(healthBar)
	if healthBar.NBPartyFramesColourHooked then
		return
	end
	healthBar.NBPartyFramesColourHooked = true
	paintedBars[#paintedBars + 1] = healthBar

	hooksecurefunc(healthBar, "SetStatusBarColor", function(self)
		if self.NBPartyFramesColourApplying or not ClassColoursEnabled() then
			return
		end
		PaintHealthBar(self, self.unit or self.NBPartyFramesUnit, true)
	end)
end

local function GetFrameHealthBar(frame)
	if not frame then
		return
	end
	if frame.healthbar then
		return frame.healthbar
	end
	if frame.HealthBarContainer then
		return frame.HealthBarContainer.HealthBar
	end
	return frame.HealthBar
end

local function HookFrameHealthBar(frame, unit)
	local healthBar = GetFrameHealthBar(frame)
	if not healthBar then
		return
	end
	unit = healthBar.unit or unit or frame.unit or frame.unitToken
	healthBar.NBPartyFramesUnit = unit
	EnsureColourHook(healthBar)
	if ClassColoursEnabled() then
		PaintHealthBar(healthBar, unit, true)
	end
end

local function HookPartyMemberFrame(frame)
	if not frame then
		return
	end
	HookFrameHealthBar(frame, frame.unitToken)
	HookFrameHealthBar(frame.PetFrame, frame.petUnitToken)

	if frame.NBPartyFramesColourMethodsHooked then
		return
	end
	frame.NBPartyFramesColourMethodsHooked = true

	local function RepaintPartyFrame()
		if ClassColoursEnabled() then
			HookFrameHealthBar(frame, frame.unitToken)
			HookFrameHealthBar(frame.PetFrame, frame.petUnitToken)
		end
	end

	for _, method in ipairs({ "ToPlayerArt", "ToVehicleArt", "UpdateMember", "UpdateArt", "Setup" }) do
		if type(frame[method]) == "function" then
			hooksecurefunc(frame, method, RepaintPartyFrame)
		end
	end
	frame:HookScript("OnShow", RepaintPartyFrame)
end

local function HookPartyMemberHealthBars()
	if not PartyFrame then
		return
	end

	local pool = PartyFrame.PartyMemberFramePool
	if pool then
		for memberFrame in pool:EnumerateActive() do
			HookPartyMemberFrame(memberFrame)
		end
	end

	for index = 1, 5 do
		HookPartyMemberFrame(PartyFrame["MemberFrame" .. index])
	end

	if CompactPartyFrame then
		for _, memberFrame in ipairs(CompactPartyFrame.memberUnitFrames or {}) do
			HookFrameHealthBar(memberFrame, memberFrame.displayedUnit or memberFrame.unit)
		end
		for _, petFrame in ipairs(CompactPartyFrame.petUnitFrames or {}) do
			HookFrameHealthBar(petFrame, petFrame.displayedUnit or petFrame.unit)
		end
	end
end

function NBPartyFrames.ApplyUnitFrameColours()
	local enabled = ClassColoursEnabled() and true or false
	if not enabled and not coloursWereEnabled then
		return
	end
	coloursWereEnabled = enabled

	HookFrameHealthBar(PlayerFrame, "player")
	HookFrameHealthBar(PetFrame, "pet")
	HookFrameHealthBar(TargetFrame, "target")
	HookFrameHealthBar(TargetFrameToT, "targettarget")
	HookFrameHealthBar(FocusFrame, "focus")
	HookFrameHealthBar(FocusFrameToT, "focustarget")
	HookPartyMemberHealthBars()

	for _, healthBar in ipairs(paintedBars) do
		PaintHealthBar(healthBar, healthBar.unit or healthBar.NBPartyFramesUnit, enabled)
	end
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusBar, unit)
	if statusBar and unit and statusBar.unit == unit then
		EnsureColourHook(statusBar)
		if ClassColoursEnabled() then
			PaintHealthBar(statusBar, unit, true)
		end
	end
end)

if PartyMemberFrameMixin and PartyMemberFrameMixin.UpdateMember then
	hooksecurefunc(PartyMemberFrameMixin, "UpdateMember", function(frame)
		if ClassColoursEnabled() then
			HookPartyMemberFrame(frame)
		end
	end)
end

if CompactUnitFrame_UpdateHealthColor then
	hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
		if not ClassColoursEnabled()
			or not frame
			or not CompactPartyFrame
			or frame:GetParent() ~= CompactPartyFrame
		then
			return
		end
		PaintHealthBar(frame.healthBar, frame.displayedUnit or frame.unit, true)
	end)
end


HookFrameHealthBar(PlayerFrame, "player")
HookFrameHealthBar(PetFrame, "pet")

local eventFrame = CreateFrame("Frame", "NBPartyFramesBlizzardFrameEvents")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= "NBPartyFrames" then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		NBPartyFrames.ApplyUnitFrameColours()
	elseif event == "PLAYER_LOGIN" then
		NBPartyFrames.ApplyPartyFrameScale()
		NBPartyFrames.ApplyPartyPetVisibility()
		NBPartyFrames.ApplyPartyFrameVisibility()
		C_Timer.After(0, NBPartyFrames.ApplyUnitFrameColours)

		for _, identityEvent in ipairs(identityEvents) do
			self:RegisterEvent(identityEvent)
		end

	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingPartyScale then
			NBPartyFrames.ApplyPartyFrameScale(pendingPartyScale)
		end
		if pendingPartyPetVisibility then
			NBPartyFrames.ApplyPartyPetVisibility()
		end
		if pendingPartyVisibility then
			NBPartyFrames.ApplyPartyFrameVisibility()
		end
		return
	elseif event == "GROUP_ROSTER_UPDATE"
		or event == "UI_SCALE_CHANGED"
		or event == "PLAYER_ENTERING_WORLD"
	then
		C_Timer.After(0, NBPartyFrames.ApplyPartyFrameScale)
		C_Timer.After(0, NBPartyFrames.ApplyUnitFrameColours)
	end

	if event == "UNIT_TARGET" and arg1 ~= "target" and arg1 ~= "focus" then
		return
	end
	if event == "UNIT_PET" and arg1 ~= "player" then
		return
	end
	if event ~= "ADDON_LOADED" and ClassColoursEnabled() then
		NBPartyFrames.ApplyUnitFrameColours()
	end
end)
