NBPartyFrames = NBPartyFrames or {}

local serializer = LibStub("AceSerializer-3.0", true)
local deflater = LibStub("LibDeflate", true)

local ACCOUNT_STORE_KIND = "NBPartyFramesAccountProfiles"
local ACCOUNT_STORE_VERSION = 1
local ACCOUNT_CVAR_HEADER = "nbpfProfileStoreHeader"
local ACCOUNT_CVAR_CHUNK_PREFIX = "nbpfProfileStore"
local ACCOUNT_CVAR_CHUNK_SIZE = 180
local ACCOUNT_CVAR_MAX_CHUNKS = 80

local registeredCVars = {}
local accountStoreLoaded = false
local accountStoreAvailable = false
local accountProfiles = {}
local accountDeletedProfiles = {}

local function RegisterProfileCVar(name)
	if registeredCVars[name] then
		return true
	end
	if not C_CVar or not C_CVar.RegisterCVar or not C_CVar.GetCVar then
		return false
	end

	pcall(C_CVar.RegisterCVar, name, "")
	local success, value = pcall(C_CVar.GetCVar, name)
	if success and value ~= nil then
		registeredCVars[name] = true
		return true
	end
	return false
end

local function ReadProfileCVar(name)
	if not RegisterProfileCVar(name) then
		return
	end
	local success, value = pcall(C_CVar.GetCVar, name)
	if success then
		return value
	end
end

local function WriteProfileCVar(name, value)
	if not RegisterProfileCVar(name) or not C_CVar.SetCVar then
		return false
	end
	local success, result = pcall(C_CVar.SetCVar, name, value)
	return success and result ~= false
end

local function GetChunkName(index)
	return ACCOUNT_CVAR_CHUNK_PREFIX .. string.format("%02d", index)
end

local function LoadAccountProfileStore()
	if accountStoreLoaded then
		return accountProfiles, accountDeletedProfiles
	end
	accountStoreLoaded = true

	if not serializer or not deflater then
		return accountProfiles, accountDeletedProfiles
	end

	local header = ReadProfileCVar(ACCOUNT_CVAR_HEADER)
	if header == nil then
		return accountProfiles, accountDeletedProfiles
	end
	accountStoreAvailable = true

	local count, encodedLength = header:match("^1:(%d+):(%d+)$")
	count = tonumber(count)
	encodedLength = tonumber(encodedLength)
	if not count or not encodedLength or count < 1 or count > ACCOUNT_CVAR_MAX_CHUNKS then
		return accountProfiles, accountDeletedProfiles
	end

	local chunks = {}
	for index = 1, count do
		local chunk = ReadProfileCVar(GetChunkName(index))
		if not chunk then
			return accountProfiles, accountDeletedProfiles
		end
		chunks[index] = chunk
	end
	local encoded = table.concat(chunks)
	if #encoded ~= encodedLength then
		return accountProfiles, accountDeletedProfiles
	end

	local decoded = deflater:DecodeForPrint(encoded)
	local serialized = decoded and deflater:DecompressDeflate(decoded)
	if not serialized then
		return accountProfiles, accountDeletedProfiles
	end

	local success, payload = serializer:Deserialize(serialized)
	if not success
		or type(payload) ~= "table"
		or payload.kind ~= ACCOUNT_STORE_KIND
		or payload.version ~= ACCOUNT_STORE_VERSION
		or type(payload.profiles) ~= "table"
	then
		return accountProfiles, accountDeletedProfiles
	end

	accountProfiles = payload.profiles
	accountDeletedProfiles = type(payload.deletedProfiles) == "table" and payload.deletedProfiles or {}
	return accountProfiles, accountDeletedProfiles
end

local function SaveAccountProfileStore(profiles, deletedProfiles)
	if not serializer or not deflater then
		return false
	end

	local serialized = serializer:Serialize({
		kind = ACCOUNT_STORE_KIND,
		version = ACCOUNT_STORE_VERSION,
		profiles = profiles,
		deletedProfiles = deletedProfiles,
	})
	local compressed = deflater:CompressDeflate(serialized)
	local encoded = compressed and deflater:EncodeForPrint(compressed)
	if not encoded then
		return false
	end

	local chunkCount = math.ceil(#encoded / ACCOUNT_CVAR_CHUNK_SIZE)
	if chunkCount < 1 or chunkCount > ACCOUNT_CVAR_MAX_CHUNKS then
		return false
	end

	local oldHeader = ReadProfileCVar(ACCOUNT_CVAR_HEADER)
	if oldHeader == nil then
		accountStoreAvailable = false
		return false
	end
	accountStoreAvailable = true
	local oldCount = tonumber(oldHeader:match("^1:(%d+):%d+$")) or 0
	local writeCount = math.max(chunkCount, math.min(oldCount, ACCOUNT_CVAR_MAX_CHUNKS))

	for index = 1, writeCount do
		local value = ""
		if index <= chunkCount then
			local first = (index - 1) * ACCOUNT_CVAR_CHUNK_SIZE + 1
			value = encoded:sub(first, first + ACCOUNT_CVAR_CHUNK_SIZE - 1)
		end
		if not WriteProfileCVar(GetChunkName(index), value) then
			return false
		end
	end

	if not WriteProfileCVar(ACCOUNT_CVAR_HEADER, "1:" .. chunkCount .. ":" .. #encoded) then
		return false
	end

	accountStoreAvailable = true
	accountProfiles = profiles
	accountDeletedProfiles = deletedProfiles
	return true
end

function NBPartyFrames.IsAccountProfileStoreAvailable()
	LoadAccountProfileStore()
	return accountStoreAvailable
end

local function DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
	end
	return copy
end

local function CopyInto(destination, source)
	local keys = {}
	for key in pairs(destination) do
		keys[#keys + 1] = key
	end
	for _, key in ipairs(keys) do
		destination[key] = nil
	end
	for key, value in pairs(source) do
		destination[DeepCopy(key)] = DeepCopy(value)
	end
end

local function NormalizeProfileName(name)
	if type(name) ~= "string" then
		return
	end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return
	end
	return name:sub(1, 32)
end

local function EnsureStores()
	if type(NBPartyFramesProfilesDB) ~= "table" then
		NBPartyFramesProfilesDB = {}
	end
	if type(NBPartyFramesProfilesDB.profiles) ~= "table" then
		NBPartyFramesProfilesDB.profiles = {}
	end
	if type(NBPartyFramesProfilesDB.deletedProfiles) ~= "table" then
		NBPartyFramesProfilesDB.deletedProfiles = {}
	end

	NBPartyFramesCharDB = type(NBPartyFramesCharDB) == "table" and NBPartyFramesCharDB or {}
	if type(NBPartyFramesCharDB.profiles) ~= "table" then
		NBPartyFramesCharDB.profiles = {}
	end

	local shared = NBPartyFramesProfilesDB.profiles
	local character = NBPartyFramesCharDB.profiles
	local deleted = NBPartyFramesProfilesDB.deletedProfiles
	local cvarProfiles, cvarDeleted = LoadAccountProfileStore()

	for name in pairs(cvarDeleted) do
		deleted[name] = true
		shared[name] = nil
		character[name] = nil
	end
	for name, profile in pairs(cvarProfiles) do
		if not deleted[name] and type(profile) == "table" then
			shared[name] = DeepCopy(profile)
		end
	end

	for name, profile in pairs(character) do
		if not deleted[name] and shared[name] == nil and type(profile) == "table" then
			shared[name] = DeepCopy(profile)
		end
	end
	for name in pairs(deleted) do
		shared[name] = nil
		character[name] = nil
	end
	for name, profile in pairs(shared) do
		if type(profile) == "table" then
			character[name] = DeepCopy(profile)
		end
	end

	return shared, character, deleted
end

local function WriteProfile(name, profile)
	local shared, character, deleted = EnsureStores()
	shared[name] = DeepCopy(profile)
	character[name] = DeepCopy(profile)
	deleted[name] = nil
	return SaveAccountProfileStore(shared, deleted)
end

local function PersistActiveProfile()
	local name = NormalizeProfileName(NBPartyFramesCharDB and NBPartyFramesCharDB.activeProfile)
	if not name then
		return
	end
	local shared = EnsureStores()
	if type(shared[name]) == "table" then
		WriteProfile(name, NBPartyFramesDB)
	end
end

function NBPartyFrames.InitializeProfiles()
	local shared, character, deleted = EnsureStores()
	local pending = NBPartyFramesCharDB.pendingProfile
	local name
	local profile

	if type(pending) == "table" then
		name = NormalizeProfileName(pending.name)
		if name and type(pending.profile) == "table" then
			profile = pending.profile
			shared[name] = DeepCopy(profile)
			character[name] = DeepCopy(profile)
			deleted[name] = nil
		end
	end
	NBPartyFramesCharDB.pendingProfile = nil

	SaveAccountProfileStore(shared, deleted)

	if type(profile) ~= "table" then
		name = NormalizeProfileName(NBPartyFramesCharDB.activeProfile)
		profile = name and shared[name]
	end
	if type(profile) == "table" then
		CopyInto(NBPartyFramesDB, profile)
		NBPartyFramesCharDB.activeProfile = name
	else
		NBPartyFramesCharDB.activeProfile = nil
	end
end

function NBPartyFrames.GetActiveProfile()
	return NormalizeProfileName(NBPartyFramesCharDB and NBPartyFramesCharDB.activeProfile)
end

function NBPartyFrames.GetProfileNames()
	local shared = EnsureStores()
	local names = {}
	for name, profile in pairs(shared) do
		if type(name) == "string" and type(profile) == "table" then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(left, right)
		return string.lower(left) < string.lower(right)
	end)
	return names
end

function NBPartyFrames.SaveProfile(name)
	name = NormalizeProfileName(name)
	if not name then
		return false, "Please enter a profile name."
	end
	local accountSaved = WriteProfile(name, NBPartyFramesDB)
	NBPartyFramesCharDB.activeProfile = name
	if accountSaved then
		return true, "Profile '" .. name .. "' saved account-wide."
	end
	return true, "Profile '" .. name .. "' saved (account-wide storage unavailable)."
end

function NBPartyFrames.LoadProfile(name)
	name = NormalizeProfileName(name)
	if not name then
		return false, "Please enter a profile name."
	end
	if InCombatLockdown() then
		return false, "Profiles cannot be switched during combat."
	end
	local shared = EnsureStores()
	local profile = shared[name]
	if type(profile) ~= "table" then
		return false, "Profile '" .. name .. "' was not found."
	end

	local active = NBPartyFrames.GetActiveProfile()
	if active and active ~= name then
		PersistActiveProfile()
	end
	CopyInto(NBPartyFramesDB, profile)
	NBPartyFrames.ApplyDatabaseDefaults()
	NBPartyFrames.ApplyGroupWindowDefaults()
	NBPartyFramesCharDB.activeProfile = name
	NBPartyFramesCharDB.pendingProfile = nil
	NBPartyFramesCharDB.db = NBPartyFramesDB

	NBPartyFrames.ApplyUnitFrameColours()
	NBPartyFrames.ApplyPartyFrameScale()
	NBPartyFrames.ApplyPartyFrameVisibility()
	NBPartyFrames.ApplyPartyMemberFramePositions()
	NBPartyFrames.ApplyPartyFramePreview()
	NBPartyFrames.SetEditMode(NBPartyFramesDB.editMode)
	NBPartyFrames.SetGridVisible(NBPartyFramesDB.showGrid)
	if NBPartyFrames.RefreshSettingsPanels then
		NBPartyFrames.RefreshSettingsPanels()
	end
	return true, "Profile '" .. name .. "' loaded."
end

function NBPartyFrames.DeleteProfile(name)
	name = NormalizeProfileName(name)
	if not name then
		return false, "Please enter a profile name."
	end
	local shared, character, deleted = EnsureStores()
	if type(shared[name]) ~= "table" and type(character[name]) ~= "table" then
		return false, "Profile '" .. name .. "' was not found."
	end
	shared[name] = nil
	character[name] = nil
	deleted[name] = true
	if NBPartyFramesCharDB.activeProfile == name then
		NBPartyFramesCharDB.activeProfile = nil
	end
	local accountSaved = SaveAccountProfileStore(shared, deleted)
	if accountSaved then
		return true, "Profile '" .. name .. "' deleted account-wide."
	end
	return true, "Profile '" .. name .. "' deleted locally (account-wide storage unavailable)."
end

local eventFrame = CreateFrame("Frame", "NBPartyFramesProfileEvents")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", PersistActiveProfile)
