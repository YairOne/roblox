-- NpcSquareSystem (combat subsystem upgrade)
-- This file focuses on combat behavior upgrades requested by design:
-- 1) soldiers enter a fighting stance as they close in,
-- 2) soldiers perform short dash steps (forward/back/left/right) while dueling.

local function normalizeAnimId(id)
	if not id then return nil end
	id = tostring(id)
	if id == "" or id == "0" or id == "rbxassetid://0" then return nil end
	if not id:find("rbxassetid://") then
		id = "rbxassetid://" .. id
	end
	return id
end

local function distXZ(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx*dx + dz*dz)
end

local function moveToward(model, currentPos, targetPos, dt, speed)
	local dir = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
	if dir.Magnitude < 0.01 then return false end
	local step = math.min(dir.Magnitude, speed * dt)
	local newPos = currentPos + dir.Unit * step
	model:PivotTo(CFrame.lookAt(newPos, newPos + dir.Unit))
	return true
end

-- New combat move animations
local DASH_FORWARD_ANIM_ID  = "rbxassetid://102943968856482"
local DASH_BACK_ANIM_ID     = "rbxassetid://111268221240880"
local DASH_LEFT_ANIM_ID     = "rbxassetid://117664259628631"
local DASH_RIGHT_ANIM_ID    = "rbxassetid://132386621141954"
local FIGHT_STANCE_ANIM_ID  = "rbxassetid://0" -- optional; only used if set to a valid asset id

-- Combat movement tuning
local FIGHT_STANCE_RADIUS   = 9.0
local DASH_TRIGGER_RADIUS   = 8.0
local DASH_DISTANCE_MIN     = 2.8
local DASH_DISTANCE_MAX     = 5.6
local DASH_COOLDOWN_MIN     = 0.45
local DASH_COOLDOWN_MAX     = 1.05
local DASH_SPEED_MULT       = 2.4

local function loadTrack(animator, animId, looped, priority)
	animId = normalizeAnimId(animId)
	if not animId then return nil end
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok or not track then return nil end
	track.Looped = looped
	track.Priority = priority
	return track
end

local function setupSoldierCombatAnimations(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local stanceTrack = loadTrack(animator, FIGHT_STANCE_ANIM_ID, true, Enum.AnimationPriority.Action)
	local dashTracks = {
		Forward = loadTrack(animator, DASH_FORWARD_ANIM_ID, false, Enum.AnimationPriority.Action),
		Back = loadTrack(animator, DASH_BACK_ANIM_ID, false, Enum.AnimationPriority.Action),
		Left = loadTrack(animator, DASH_LEFT_ANIM_ID, false, Enum.AnimationPriority.Action),
		Right = loadTrack(animator, DASH_RIGHT_ANIM_ID, false, Enum.AnimationPriority.Action),
	}

	return {
		stanceTrack = stanceTrack,
		dashTracks = dashTracks,
		inStance = false,
		lastDashAt = 0,
		nextDashDelay = math.random() * (DASH_COOLDOWN_MAX - DASH_COOLDOWN_MIN) + DASH_COOLDOWN_MIN,
	}
end

local function setFightStance(combatAnim, on)
	if not combatAnim then return end
	if combatAnim.inStance == on then return end
	combatAnim.inStance = on
	if combatAnim.stanceTrack then
		if on then
			if not combatAnim.stanceTrack.IsPlaying then
				pcall(function() combatAnim.stanceTrack:Play(0.12, 1, 1) end)
			end
		else
			if combatAnim.stanceTrack.IsPlaying then
				pcall(function() combatAnim.stanceTrack:Stop(0.1) end)
			end
		end
	end
end

local function chooseDashDirection(distanceToTarget)
	if distanceToTarget <= 3.2 then
		return "Back"
	end
	local roll = math.random()
	if roll < 0.35 then return "Forward" end
	if roll < 0.58 then return "Left" end
	if roll < 0.81 then return "Right" end
	return "Back"
end

local function performDash(model, combatAnim, targetPos, dt, speed)
	if not combatAnim then return false end
	local now = os.clock()
	if now - combatAnim.lastDashAt < combatAnim.nextDashDelay then
		return false
	end

	local myPos = model:GetPivot().Position
	local toTarget = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
	if toTarget.Magnitude < 0.001 then return false end
	local forward = toTarget.Unit
	local right = Vector3.new(forward.Z, 0, -forward.X)

	local dashDirName = chooseDashDirection(distXZ(myPos, targetPos))
	local dashDir = forward
	if dashDirName == "Back" then dashDir = -forward end
	if dashDirName == "Left" then dashDir = -right end
	if dashDirName == "Right" then dashDir = right end

	local dashDistance = math.random() * (DASH_DISTANCE_MAX - DASH_DISTANCE_MIN) + DASH_DISTANCE_MIN
	local dashTarget = myPos + dashDir * dashDistance

	local track = combatAnim.dashTracks and combatAnim.dashTracks[dashDirName]
	if track then
		pcall(function() track:Play(0.03, 1, 1) end)
	end

	combatAnim.lastDashAt = now
	combatAnim.nextDashDelay = math.random() * (DASH_COOLDOWN_MAX - DASH_COOLDOWN_MIN) + DASH_COOLDOWN_MIN
	return moveToward(model, myPos, dashTarget, dt, speed * DASH_SPEED_MULT)
end

-- Integration helper:
-- call this when the soldier has an active enemy target.
local function updateCloseCombat(model, combatAnim, targetPos, dt, speed)
	local myPos = model:GetPivot().Position
	local d = distXZ(myPos, targetPos)

	if d <= FIGHT_STANCE_RADIUS then
		setFightStance(combatAnim, true)
	else
		setFightStance(combatAnim, false)
	end

	if d <= DASH_TRIGGER_RADIUS then
		if performDash(model, combatAnim, targetPos, dt, speed) then
			return true
		end
	end

	return moveToward(model, myPos, targetPos, dt, speed)
end

-- Example usage in your existing soldier brain loop:
-- local combatAnim = setupSoldierCombatAnimations(clone)
-- ...
-- if target then
--     local moved = updateCloseCombat(clone, combatAnim, target.hrp.Position, dt, stats.Speed)
-- end

return {
	setupSoldierCombatAnimations = setupSoldierCombatAnimations,
	updateCloseCombat = updateCloseCombat,
}
