--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetClient = {}

function PetClient.init()
	-- Smooth procedural breathing/bobbing for follower pets
	local timePassed = 0
	RunService.RenderStepped:Connect(function(dt)
		timePassed += dt
		local petFolder = Workspace:FindFirstChild("PlayerPets")
		if not petFolder then return end

		for _, model in petFolder:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart then
				local billboard = model.PrimaryPart:FindFirstChildOfClass("BillboardGui")
				if billboard then
					billboard.StudsOffset = Vector3.new(0, 1.8 + math.sin(timePassed * 3) * 0.15, 0)
				end
			end
		end
	end)
end

return PetClient
