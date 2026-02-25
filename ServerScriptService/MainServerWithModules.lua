--[[
Main Server Script + Child ModuleScripts (Roblox Studio layout)

How to set up in Studio:
1) Create a Script in ServerScriptService named "MainServer".
2) Inside that Script, create these ModuleScripts:
   - Config
   - PlayerData
   - CombatService
3) Paste each module block (below) into its matching ModuleScript.
4) Paste the MAIN SCRIPT block into the MainServer Script.

Hierarchy:
ServerScriptService
└── MainServer (Script)
    ├── Config (ModuleScript)
    ├── PlayerData (ModuleScript)
    └── CombatService (ModuleScript)
]]

---------------------------------------------------------------------
-- ModuleScript: Config
---------------------------------------------------------------------
--[[
local Config = {
	STARTING_HEALTH = 100,
	SPAWN_PROTECTION_SECONDS = 3,
	BASE_DAMAGE = 15,
}

return Config
]]

---------------------------------------------------------------------
-- ModuleScript: PlayerData
---------------------------------------------------------------------
--[[
local PlayerData = {}
PlayerData._store = {}

function PlayerData.InitPlayer(player, startingHealth)
	PlayerData._store[player.UserId] = {
		Health = startingHealth,
		Score = 0,
		SpawnedAt = os.clock(),
	}
end

function PlayerData.RemovePlayer(player)
	PlayerData._store[player.UserId] = nil
end

function PlayerData.Get(player)
	return PlayerData._store[player.UserId]
end

function PlayerData.AddScore(player, amount)
	local profile = PlayerData.Get(player)
	if not profile then return end
	profile.Score += amount
end

return PlayerData
]]

---------------------------------------------------------------------
-- ModuleScript: CombatService
---------------------------------------------------------------------
--[[
local CombatService = {}

function CombatService.CanTakeDamage(profile, spawnProtectionSeconds)
	if not profile then return false end
	return (os.clock() - profile.SpawnedAt) >= spawnProtectionSeconds
end

function CombatService.ApplyDamage(profile, amount)
	if not profile then return end
	profile.Health = math.max(0, profile.Health - amount)
end

return CombatService
]]

---------------------------------------------------------------------
-- MAIN SCRIPT: MainServer (Script)
---------------------------------------------------------------------

local Players = game:GetService("Players")

local Config = require(script:WaitForChild("Config"))
local PlayerData = require(script:WaitForChild("PlayerData"))
local CombatService = require(script:WaitForChild("CombatService"))

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	local profile = PlayerData.Get(player)
	if profile then
		humanoid.Health = profile.Health
		humanoid.MaxHealth = Config.STARTING_HEALTH
	end

	humanoid.Died:Connect(function()
		local p = PlayerData.Get(player)
		if p then
			p.Health = Config.STARTING_HEALTH
		end
	end)
end

local function onPlayerAdded(player)
	PlayerData.InitPlayer(player, Config.STARTING_HEALTH)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

local function onPlayerRemoving(player)
	PlayerData.RemovePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Demo server tick: safely applies periodic damage after spawn protection.
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = PlayerData.Get(player)
			if CombatService.CanTakeDamage(profile, Config.SPAWN_PROTECTION_SECONDS) then
				CombatService.ApplyDamage(profile, Config.BASE_DAMAGE)
			end
		end
	end
end)
