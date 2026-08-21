-- ServerScriptService
-- AxiomSunshardsReward.server.lua

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	FINAL_SUNSHARDS = 999999,
	DATASTORE_NAME = "Sunshards_V1",
}

local SunshardsStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)

---------------------------------------------------------------------
-- REMOTE / END EVENT
---------------------------------------------------------------------

local gameEndedEvent = ReplicatedStorage:FindFirstChild("GameEnded")

if not gameEndedEvent then
	gameEndedEvent = Instance.new("BindableEvent")
	gameEndedEvent.Name = "GameEnded"
	gameEndedEvent.Parent = ReplicatedStorage
end

---------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------

local function getSunshards(player)
	-- Ưu tiên currency có sẵn trong player
	local existing = player:FindFirstChild("Sunshards", true)

	if existing and (
		existing:IsA("IntValue")
		or existing:IsA("NumberValue")
	) then
		return existing
	end

	-- Nếu game dùng leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local sunshards = leaderstats:FindFirstChild("Sunshards")

	if not sunshards then
		sunshards = Instance.new("IntValue")
		sunshards.Name = "Sunshards"
		sunshards.Value = 0
		sunshards.Parent = leaderstats
	end

	return sunshards
end

---------------------------------------------------------------------
-- LOAD
---------------------------------------------------------------------

local function loadPlayer(player)
	local sunshards = getSunshards(player)

	local success, savedValue = pcall(function()
		return SunshardsStore:GetAsync(
			"Sunshards_" .. player.UserId
		)
	end)

	if success and typeof(savedValue) == "number" then
		sunshards.Value = savedValue
	end
end

---------------------------------------------------------------------
-- SAVE
---------------------------------------------------------------------

local function savePlayer(player)
	local sunshards = getSunshards(player)

	if not sunshards then
		return
	end

	local value = sunshards.Value

	pcall(function()
		SunshardsStore:UpdateAsync(
			"Sunshards_" .. player.UserId,

			function(oldValue)
				oldValue = tonumber(oldValue) or 0

				return math.max(
					oldValue,
					value
				)
			end
		)
	end)
end

---------------------------------------------------------------------
-- FINAL REWARD
---------------------------------------------------------------------

local function giveFinalSunshards(player)
	local sunshards = getSunshards(player)

	if not sunshards then
		return
	end

	-- Không trừ người nào đang có trên 999999.
	sunshards.Value = math.max(
		sunshards.Value,
		CONFIG.FINAL_SUNSHARDS
	)

	task.spawn(savePlayer, player)
end

local function rewardAllPlayersAtGameEnd()
	for _, player in ipairs(Players:GetPlayers()) do
		giveFinalSunshards(player)
	end
end

---------------------------------------------------------------------
-- GAME END
---------------------------------------------------------------------

gameEndedEvent.Event:Connect(function()
	rewardAllPlayersAtGameEnd()
end)

---------------------------------------------------------------------
-- PLAYER
---------------------------------------------------------------------

Players.PlayerAdded:Connect(loadPlayer)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
end)

---------------------------------------------------------------------
-- SERVER CLOSE
---------------------------------------------------------------------

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

---------------------------------------------------------------------
-- EXISTING PLAYERS
---------------------------------------------------------------------

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

print("[AXIOM] Final Sunshards reward loaded.")
