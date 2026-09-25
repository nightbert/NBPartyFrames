NBPartyFrames = NBPartyFrames or {}

local partyOriginalParent
local pendingPartyVisibility
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:Hide()

function NBPartyFrames.GetPartyFrameScale()
	return NBPartyFramesDB.partyFrameScale or 1.0
end

function NBPartyFrames.ApplyPartyFrameScale(scale)
	scale = scale or NBPartyFrames.GetPartyFrameScale()
	PartyFrame:SetScale(scale)
	if NBPartyFrames.ApplyPartyMemberFramePositions then
		NBPartyFrames.ApplyPartyMemberFramePositions()
	end
	if NBPartyFrames.ApplyPartyFramePreview then
		NBPartyFrames.ApplyPartyFramePreview()
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
local generation = 1
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

local function IsSecret(value)
	return issecretvalue(value)
end

local function SameChannel(a, b)
	return math.floor(a * 255 + 0.5) == math.floor(b * 255 + 0.5)
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

	if useClassColours
		and healthBar.NBPartyFramesColourGeneration == generation
		and healthBar.NBPartyFramesColourUnit == unit
	then
		return
	end

	local colour, fromClass
	if useClassColours then
		colour, fromClass = GetUnitColour(unit)
	else
		colour, fromClass = GetDefaultUnitColour(unit), false
	end

	if useClassColours and healthBar.NBPartyFramesColourPainted and not IsSecret(colour.r) then
		local r, g, b, a = healthBar:GetStatusBarColor()
		if r and not IsSecret(r) and a == 1
			and SameChannel(r, colour.r)
			and SameChannel(g, colour.g)
			and SameChannel(b, colour.b)
		then
			healthBar.NBPartyFramesColourGeneration = fromClass and generation or nil
			healthBar.NBPartyFramesColourUnit = fromClass and unit or nil
			return
		end
	end

	healthBar.NBPartyFramesColourApplying = true
	healthBar:SetStatusBarDesaturated(useClassColours and true or false)
	healthBar:SetStatusBarColor(colour.r, colour.g, colour.b)
	healthBar.NBPartyFramesColourApplying = false
	healthBar.NBPartyFramesColourPainted = useClassColours and true or nil
	healthBar.NBPartyFramesColourGeneration = useClassColours and fromClass and generation or nil
	healthBar.NBPartyFramesColourUnit = useClassColours and fromClass and unit or nil
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
		self.NBPartyFramesColourGeneration = nil
		self.NBPartyFramesColourUnit = nil
		PaintHealthBar(self, self.unit, true)
	end)
end

local function HookFrameHealthBar(frame, unit)
	if not frame or not frame.healthbar then
		return
	end
	EnsureColourHook(frame.healthbar)
	if ClassColoursEnabled() then
		PaintHealthBar(frame.healthbar, unit, true)
	end
end

function NBPartyFrames.ApplyUnitFrameColours()
	local enabled = ClassColoursEnabled() and true or false
	if not enabled and not coloursWereEnabled then
		return
	end
	coloursWereEnabled = enabled
	generation = generation + 1

	HookFrameHealthBar(PlayerFrame, "player")
	HookFrameHealthBar(PetFrame, "pet")
	HookFrameHealthBar(TargetFrame, "target")
	HookFrameHealthBar(TargetFrameToT, "targettarget")
	HookFrameHealthBar(FocusFrame, "focus")
	HookFrameHealthBar(FocusFrameToT, "focustarget")

	for _, healthBar in ipairs(paintedBars) do
		PaintHealthBar(healthBar, healthBar.unit, enabled)
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
		NBPartyFrames.ApplyPartyFrameVisibility()

		for _, identityEvent in ipairs(identityEvents) do
			self:RegisterEvent(identityEvent)
		end

	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingPartyVisibility then
			NBPartyFrames.ApplyPartyFrameVisibility()
		end
		return
	elseif event == "GROUP_ROSTER_UPDATE"
		or event == "UI_SCALE_CHANGED"
		or event == "PLAYER_ENTERING_WORLD"
	then
		C_Timer.After(0, NBPartyFrames.ApplyPartyFrameScale)
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
