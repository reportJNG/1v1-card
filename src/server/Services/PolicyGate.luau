--!strict
-- Fetches each player's PolicyService info once on join and keeps two separate answers
-- (Domain/PolicyRules): may they buy paid random items, and may they trade paid items.
-- Fails closed: until PolicyService answers, or if it keeps failing, both are "no".
-- Attributes are mirrored on the Player so client UI can hide offers; the server re-checks
-- PolicyGate on every request and never trusts the attribute.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyRules = require(ReplicatedStorage:WaitForChild("Shared").Domain.PolicyRules)

type PolicyState = PolicyRules.PolicyState

local PolicyGate = {}

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)

local states: { [Player]: PolicyState } = {}
local settled: { [Player]: boolean } = {} -- the lookup finished (answered or gave up)
local MAX_ATTEMPTS = 3

local function publish(player: Player, state: PolicyState)
	player:SetAttribute("PolicyKnown", state.known)
	player:SetAttribute("PaidRandomItemsAllowed", PolicyRules.canPurchasePaidRandomItems(state))
	player:SetAttribute("PaidItemTradingAllowed", PolicyRules.canTradePaidItems(state))
	print(
		`[PolicyGate] {player.Name} ({player.UserId}) known={state.known}`
			.. ` restricted={state.paidRandomItemsRestricted} tradingAllowed={state.paidItemTradingAllowed}`
			.. ` -> purchase={PolicyRules.canPurchasePaidRandomItems(state)} trade={PolicyRules.canTradePaidItems(
				state
			)}`
	)
end

local function fetch(player: Player)
	for attempt = 1, MAX_ATTEMPTS do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if not player.Parent then
			return
		end
		if ok then
			local state = PolicyRules.fromPolicyInfo(info)
			states[player] = state
			settled[player] = true
			publish(player, state)
			return
		end
		warn(`[PolicyGate] policy lookup failed for {player.UserId} (attempt {attempt}): {info}`)
		task.wait(2 ^ attempt)
	end
	-- Still unknown: stays fail-closed for this session.
	settled[player] = true
end

function PolicyGate.get(player: Player): PolicyState
	return states[player] or PolicyRules.UNKNOWN
end

-- Waits (yielding) until the lookup has finished or the timeout passes, then returns the state.
-- Used by receipt delivery right after join, so a valid purchase isn't held just because the
-- policy answer hadn't arrived yet.
function PolicyGate.waitUntilSettled(player: Player, timeout: number): PolicyState
	local deadline = os.clock() + timeout
	while not settled[player] and player.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	return PolicyGate.get(player)
end

-- Server-side trading check for the V2 player store. V1 has no trading operations; anything
-- that ever moves a card between players must call this first.
function PolicyGate.canTradeCopy(player: Player, copy: Types.CardCopy): boolean
	return PolicyRules.isCopyTradeEligible(PolicyGate.get(player), copy)
end

function PolicyGate.init()
	Players.PlayerAdded:Connect(function(player)
		states[player] = PolicyRules.UNKNOWN
		publish(player, PolicyRules.UNKNOWN)
		task.spawn(fetch, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		settled[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if states[player] == nil then
			states[player] = PolicyRules.UNKNOWN
			task.spawn(fetch, player)
		end
	end
end

return PolicyGate
