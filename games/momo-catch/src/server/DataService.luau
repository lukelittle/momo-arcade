--!strict
--[[
	DataService: loads and saves each player's high score, all-time momos caught, and
	whether they've seen the easter egg.

	- Every DataStore call is wrapped in pcall and retried with backoff.
	- Saves use UpdateAsync and *merge* (max high score, add the unsaved catch count),
	  so a failed load can never wipe real progress.
	- Saves on round end, PlayerRemoving and BindToClose.
	- If DataStores aren't available (e.g. Studio without "Enable Studio Access to API
	  Services"), it warns once and the game keeps working without saving.

	Public stats are mirrored to Player attributes for the UI:
	  MomoDataReady (bool), MomoHighScore (number), MomoTotalCaught (number)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.MomoCatch.Config)

export type Profile = {
	highScore: number,
	totalCaught: number,
	easterEggShown: boolean,
}

type Entry = {
	profile: Profile,
	ready: boolean, -- load attempt finished (successfully or not)
	pendingCaught: number, -- catches not yet written to the DataStore
	dirty: boolean,
	saving: boolean,
}

local DataService = {}

local entries: { [Player]: Entry } = {}
local store: DataStore? = nil
local storeDisabled = false

local function disableStore(reason: string)
	if storeDisabled then
		return
	end
	storeDisabled = true
	store = nil
	warn(
		"[MomoCatch] Saving is off for this session: "
			.. reason
			.. "\n  In Studio: Home > Game Settings > Security > Enable Studio Access to API Services"
			.. " (the place must be published first). The game still works, it just won't remember scores."
	)
end

local function getStore(): DataStore?
	if storeDisabled then
		return nil
	end
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
		return result
	end
	disableStore(tostring(result))
	return nil
end

-- Errors that will never succeed on retry (no API access / unpublished place).
local function isPermanentError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio access", 1, true) ~= nil
		or string.find(lower, "403", 1, true) ~= nil
		or string.find(lower, "publish", 1, true) ~= nil
		or string.find(lower, "not allowed", 1, true) ~= nil
end

-- Runs `fn` with retries. Returns (true, result) or (false, errorMessage).
local function withRetries<T>(label: string, fn: () -> T): (boolean, T | string)
	local lastError = "unknown error"
	for attempt = 1, Config.Data.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if isPermanentError(lastError) then
			disableStore(lastError)
			break
		end
		if attempt < Config.Data.Retries then
			warn(`[MomoCatch] {label} failed (attempt {attempt}): {lastError}`)
			task.wait(Config.Data.RetryBaseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

local function keyFor(player: Player): string
	return Config.Data.KeyPrefix .. tostring(player.UserId)
end

local function sanitize(raw: any): Profile
	local data = if type(raw) == "table" then raw else {}
	local high = tonumber(data.highScore) or 0
	local total = tonumber(data.totalCaught) or 0
	return {
		highScore = math.max(0, math.floor(high)),
		totalCaught = math.max(0, math.floor(total)),
		easterEggShown = data.easterEggShown == true,
	}
end

local function publish(player: Player, entry: Entry)
	player:SetAttribute("MomoHighScore", entry.profile.highScore)
	player:SetAttribute("MomoTotalCaught", entry.profile.totalCaught)
	player:SetAttribute("MomoDataReady", entry.ready)
end

local function load(player: Player)
	local entry: Entry = {
		profile = { highScore = 0, totalCaught = 0, easterEggShown = false },
		ready = false,
		pendingCaught = 0,
		dirty = false,
		saving = false,
	}
	entries[player] = entry
	publish(player, entry)

	local dataStore = getStore()
	if dataStore then
		local ok, result = withRetries("Load", function()
			return (dataStore:GetAsync(keyFor(player)))
		end)
		if entries[player] ~= entry then
			return -- player left while we were loading
		end
		if ok then
			local saved = sanitize(result)
			entry.profile.highScore = math.max(entry.profile.highScore, saved.highScore)
			entry.profile.totalCaught = saved.totalCaught + entry.pendingCaught
			entry.profile.easterEggShown = entry.profile.easterEggShown or saved.easterEggShown
		elseif not storeDisabled then
			warn(`[MomoCatch] Could not load data for {player.Name}; playing with fresh stats.`, result)
		end
	end

	entry.ready = true
	publish(player, entry)
end

local function save(player: Player, entry: Entry)
	-- Only one save per player at a time; a second caller waits and then saves
	-- anything that changed in the meantime.
	while entry.saving do
		task.wait(0.1)
	end
	if not entry.dirty then
		return
	end
	local dataStore = getStore()
	if not dataStore then
		return
	end

	entry.saving = true
	entry.dirty = false
	local caughtDelta = entry.pendingCaught
	local highScore = entry.profile.highScore
	local eggShown = entry.profile.easterEggShown

	local ok, err = withRetries("Save", function()
		return (
			dataStore:UpdateAsync(keyFor(player), function(old: any)
				local merged = sanitize(old)
				merged.totalCaught += caughtDelta
				merged.highScore = math.max(merged.highScore, highScore)
				merged.easterEggShown = merged.easterEggShown or eggShown
				return merged
			end)
		)
	end)

	if ok then
		entry.pendingCaught -= caughtDelta
	else
		entry.dirty = true
		if not storeDisabled then
			warn(`[MomoCatch] Could not save data for {player.Name}:`, err)
		end
	end
	entry.saving = false
end

function DataService.init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry then
			save(player, entry)
			if entries[player] == entry then
				entries[player] = nil
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, entry in table.clone(entries) do
			pending += 1
			task.spawn(function()
				save(player, entry)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.isReady(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.ready
end

function DataService.getProfile(player: Player): Profile?
	local entry = entries[player]
	return if entry then table.clone(entry.profile) else nil
end

-- Counts good momos caught (all-time).
function DataService.addCaught(player: Player, count: number)
	local entry = entries[player]
	if not entry or count <= 0 then
		return
	end
	entry.profile.totalCaught += count
	entry.pendingCaught += count
	entry.dirty = true
	player:SetAttribute("MomoTotalCaught", entry.profile.totalCaught)
end

-- Records a finished round. Returns true if it's a new personal best.
function DataService.submitScore(player: Player, score: number): boolean
	local entry = entries[player]
	if not entry or score <= entry.profile.highScore then
		return false
	end
	entry.profile.highScore = score
	entry.dirty = true
	player:SetAttribute("MomoHighScore", score)
	return true
end

-- True exactly once: the first time all-time catches reach the threshold.
function DataService.claimEasterEgg(player: Player): boolean
	local entry = entries[player]
	if not entry or entry.profile.easterEggShown then
		return false
	end
	if entry.profile.totalCaught < Config.EasterEgg.Threshold then
		return false
	end
	entry.profile.easterEggShown = true
	entry.dirty = true
	return true
end

function DataService.saveAsync(player: Player)
	local entry = entries[player]
	if entry then
		task.spawn(save, player, entry)
	end
end

return DataService
