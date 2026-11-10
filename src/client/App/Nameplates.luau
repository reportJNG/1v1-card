--!strict
-- A clean plate over every other player (BAD_GUI_THINKING_AND_UI section 2.3): their name in big
-- outlined text and their trophies with the trophy icon (the server's "Trophies" attribute).
-- Replaces Roblox's default name display, which is plain text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Billboard = require(Shared.Ui.Billboard)

local Nameplates = {}

local function attach(player: Player, character: Model, holder: Instance)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if head == nil or humanoid == nil then
		return
	end
	(humanoid :: Humanoid).DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local name = Billboard.make({
		name = `Name_{player.UserId}`,
		text = player.DisplayName,
		color = Color3.new(1, 1, 1),
		studs = 1.1,
		offset = Vector3.new(0, 3.1, 0),
		maxDistance = Billboard.Kind.player.maxDistance,
	})
	name.Adornee = head
	name.Parent = holder
	local trophies = Billboard.make({
		name = `Trophies_{player.UserId}`,
		text = tostring(player:GetAttribute("Trophies") or 0),
		icon = "icon_trophy",
		gradient = Billboard.Gold,
		studs = 0.9,
		offset = Vector3.new(0, 2.15, 0),
		maxDistance = Billboard.Kind.player.maxDistance,
	})
	trophies.Adornee = head
	trophies.Parent = holder
	local conn = player:GetAttributeChangedSignal("Trophies"):Connect(function()
		local label = trophies:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Text = tostring(player:GetAttribute("Trophies") or 0)
		end
	end)
	character.Destroying:Connect(function()
		conn:Disconnect()
		name:Destroy()
		trophies:Destroy()
	end)
end

function Nameplates.start()
	local me = Players.LocalPlayer
	if me == nil then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "Nameplates"
	holder.Parent = me:WaitForChild("PlayerGui")
	local function watch(player: Player)
		if player == me then
			return -- your own name stays off your screen
		end
		player.CharacterAdded:Connect(function(character)
			attach(player, character, holder)
		end)
		if player.Character then
			task.spawn(attach, player, player.Character, holder)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Nameplates
