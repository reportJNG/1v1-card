--!strict
-- The in-world prompts built by Server/World/WorldBuilder and HubBuilder: Harvest a node, Sell at
-- the merchant, Challenge the Guardian, step through a world's Back to Lobby portal, and the hub's
-- Arena / Worlds portal / egg stall (which only open a screen). The prompt only starts a request; the server checks range, cooldown
-- and inventory itself. A harvested node dims for this player until it respawns.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Guardians = require(Shared.Config.Guardians)

local WorldInteraction = {}

-- The world an instance belongs to: the nearest ancestor with a WorldId attribute (World01..10).
local function worldOf(inst: Instance): number?
	local at: Instance? = inst.Parent
	while at do
		local id = at:GetAttribute("WorldId")
		if typeof(id) == "number" then
			return id
		end
		at = at.Parent
	end
	return nil
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
				-- Dim the node's mesh (a child of the prompt part) until it respawns for this player.
				local function dim(amount: number)
					for _, d in part:GetDescendants() do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = amount
						end
					end
				end
				dim(0.7)
				prompt.Enabled = false
				task.delay(math.max(1, v.readyIn), function()
					dim(0)
					prompt.Enabled = true
				end)
			end
		elseif prompt.Name == "WorldLobby" then
			ctx.request("World.Hub")
		elseif prompt.Name == "Sell" then
			ctx.open("Merchant")
		elseif prompt.Name == "HubArena" then
			ctx.open("Play")
		elseif prompt.Name == "HubPortal" then
			ctx.open("Worlds")
		elseif prompt.Name == "HubShop" then
			ctx.open("Shop")
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
