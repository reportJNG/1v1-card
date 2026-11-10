--!strict
-- The in-world prompts built by Server/World/WorldBuilder and HubBuilder: Harvest a node, Sell at
-- the merchant, Challenge the Guardian, step through a world's Back to Lobby portal, and the lobby's
-- Arena gate / Worlds portal / egg pavilion / quest board / daily shrine (which only open a
-- screen). The lobby's "!" over the quest board and its DAILY sign follow the profile. The prompt only starts a request; the server checks range, cooldown
-- and inventory itself. A harvested node dims for this player until it respawns.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guardians = require(Shared.Config.Guardians)
local HudBadges = require(Shared.Ui.HudBadges)
local Ui = require(script.Parent.Ui)

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

-- A node's name label steps aside while its own prompt is up (the prompt already names it).
local function labelOf(prompt: ProximityPrompt): BillboardGui?
	local part = prompt.Parent
	local label = part and part:FindFirstChild("NodeLabel")
	return if label and label:IsA("BillboardGui") then label else nil
end

-- The lobby's live markers: "!" over the quest board while a quest is ready, the DAILY sign and the
-- shrine's chest glow while today's reward waits. Display only; claiming goes through the server.
local function lobbyMarkers(ctx: any)
	local hub = workspace:FindFirstChild("Hub")
	local view = ctx.state.view
	if hub == nil or view == nil then
		return
	end
	local alert = hub:FindFirstChild("QuestAlert")
	local gui = alert and alert:FindFirstChildOfClass("BillboardGui")
	if gui then
		gui.Enabled = HudBadges.questReady(view)
	end
	local daily = HudBadges.dailyReady(view, ctx.now())
	local sign = hub:FindFirstChild("Sign_DAILY")
	local signGui = sign and sign:FindFirstChildOfClass("BillboardGui")
	if signGui then
		signGui.Enabled = daily
	end
	local chest = hub:FindFirstChild("DailyChest", true)
	local glow = chest and chest:FindFirstChildOfClass("PointLight")
	if glow then
		glow.Brightness = if daily then 2.5 else 0
	end
end

function WorldInteraction.start(ctx: any)
	ctx.state.changed:connect(function(what: string)
		if what == "profile" then
			lobbyMarkers(ctx)
		end
	end)
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if hub then
			hub:WaitForChild("QuestAlert", 30)
			lobbyMarkers(ctx)
		end
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local label = if prompt.Name == "Harvest" then labelOf(prompt) else nil
		if label then
			label.Enabled = false
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local label = if prompt.Name == "Harvest" then labelOf(prompt) else nil
		if label then
			label.Enabled = prompt.Enabled -- still spent: stays hidden until it respawns
		end
	end)
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
				-- "+2" with the item's own icon pops out of the node, and the items fly to the bag.
				Ui.sound("sparkle")
				ctx.popAt(part, { text = `+{v.count}`, itemId = v.itemId, tone = "green", size = 52 })
				ctx.fly(part, "bag", { itemId = v.itemId, count = math.min(v.count, 4) })
				if v.rareItemId then
					task.delay(0.3, function()
						ctx.popAt(
							part.Position + Vector3.new(0, 3, 0),
							{ text = `RARE +{v.rareCount}`, itemId = v.rareItemId, tone = "gold", size = 52 }
						)
						ctx.fly(part, "bag", { itemId = v.rareItemId, count = v.rareCount })
					end)
				end
				-- Dim the node's mesh (a child of the prompt part) until it respawns for this player.
				local function dim(amount: number)
					for _, d in part:GetDescendants() do
						if d:IsA("BasePart") then
							d.LocalTransparencyModifier = amount
						end
					end
					-- The node's name only floats over nodes that are ready to harvest.
					local nodeLabel = part:FindFirstChild("NodeLabel")
					if nodeLabel and nodeLabel:IsA("BillboardGui") then
						nodeLabel.Enabled = amount == 0
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
			ctx.open("Merchant", { source = part })
		elseif prompt.Name == "HubArena" then
			ctx.open("Play")
		elseif prompt.Name == "HubPortal" then
			ctx.open("Worlds")
		elseif prompt.Name == "HubShop" then
			ctx.open("Shop")
		elseif prompt.Name == "HubQuests" or prompt.Name == "HubDaily" then
			ctx.open("Quests")
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
