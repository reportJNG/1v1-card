--!strict
-- The in-world prompts built by Server/World/WorldBuilder: Harvest a node, Sell at the merchant,
-- Challenge the Guardian. The prompt only starts a request; the server checks range, cooldown
-- and inventory itself. A harvested node dims for this player until it respawns.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Guardians = require(Shared.Config.Guardians)

local WorldInteraction = {}

local function worldOf(inst: Instance): number?
	local model = inst:FindFirstAncestorWhichIsA("Model")
	return model and model:GetAttribute("WorldId") :: number?
end

function WorldInteraction.start(ctx: any)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local part = prompt.Parent
		if part == nil or not part:IsA("BasePart") then
			return
		end
		if prompt.Name == "Harvest" then
			local nodeId = part:GetAttribute("NodeId")
			if typeof(nodeId) ~= "string" then
				return
			end
			local reply = ctx.request("Farm.Harvest", { nodeId = nodeId })
			if reply.ok then
				local v = reply.value
				local text = `+{v.count} {Items.ById[v.itemId].displayName}`
				if v.rareItemId then
					text ..= ` · rare: +{v.rareCount} {Items.ById[v.rareItemId].displayName}!`
				end
				ctx.toast(text, "good")
				local before = part.Transparency
				part.LocalTransparencyModifier = 0.7
				prompt.Enabled = false
				task.delay(math.max(1, v.readyIn), function()
					part.LocalTransparencyModifier = 0
					prompt.Enabled = true
					local _ = before
				end)
			end
		elseif prompt.Name == "Sell" then
			ctx.open("Merchant")
		elseif prompt.Name == "Challenge" then
			local worldId = worldOf(part)
			if worldId == nil then
				return
			end
			local g = Guardians.ByWorld[worldId]
			ctx.confirm(
				"Guardian Trial",
				`Fight {g.displayName} with your deck? A first win pays trophies, Coins, Gems and a Golden egg.`,
				"Fight",
				function()
					ctx.request("Trial.Start", { worldId = worldId })
				end
			)
		end
	end)
end

return WorldInteraction
