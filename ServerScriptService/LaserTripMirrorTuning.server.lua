-- Laser Trip mirror tuning
-- Expands mirror hinge travel so players can rotate far enough left/right
-- to reliably hit the puzzle target.

local Workspace = game:GetService("Workspace")

local MIN_LEFT_ANGLE = -130
local MIN_RIGHT_ANGLE = 130

local function isLaserTripMirrorConstraint(constraint)
	if not constraint:IsA("HingeConstraint") then
		return false
	end

	local name = string.lower(constraint.Name)
	if string.find(name, "mirror", 1, true) then
		return true
	end

	local parent = constraint.Parent
	while parent and parent ~= Workspace do
		local parentName = string.lower(parent.Name)
		if (string.find(parentName, "laser", 1, true) and string.find(parentName, "trip", 1, true))
			or string.find(parentName, "mirror", 1, true)
		then
			return true
		end
		parent = parent.Parent
	end

	return false
end

local function widenMirrorTravel(constraint)
	if not isLaserTripMirrorConstraint(constraint) then
		return
	end

	constraint.LimitsEnabled = true

	if constraint.LowerAngle > MIN_LEFT_ANGLE then
		constraint.LowerAngle = MIN_LEFT_ANGLE
	end

	if constraint.UpperAngle < MIN_RIGHT_ANGLE then
		constraint.UpperAngle = MIN_RIGHT_ANGLE
	end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("HingeConstraint") then
		widenMirrorTravel(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("HingeConstraint") then
		widenMirrorTravel(descendant)
	end
end)
