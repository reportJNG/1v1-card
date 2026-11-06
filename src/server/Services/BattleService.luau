--!strict
-- Hosts battles on this server (Server/Battle/MatchHost) and settles them:
--   Ranked  matches from the matchmaker (MatchmakingService.startLocal or a reserved battle
--           server); both profiles are loaded here, and Settlement pays each side once
--   Trial   a Guardian Trial against the AI; a first win grants Trials.grantClear
-- Remotes: Battle.Pick, Battle.ChooseNext, Battle.Forfeit, Trial.Start (all via Dispatcher).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)
local Settlement = require(Shared.Domain.Settlement)
local Trials = require(Shared.Domain.Trials)
local Quests = require(Shared.Domain.Quests)
local Economy = require(Shared.Config.Economy)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local MatchHost = require(Server:WaitForChild("Battle").MatchHost)
local MatchRunner = require(Server.Battle.MatchRunner)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Telemetry)

local RECONNECT_SECONDS = 30

local BattleService = {}

local host: MatchHost.MatchHost? = nil
local lastTrial: { [number]: number } = {} -- userId -> os.clock() of the last Trial start
local endHooks: { (userId: number, record: MatchHost.Record, won: boolean) -> () } = {}
local rng = Random.new()

local function getHost(): MatchHost.MatchHost
	assert(host, "BattleService not initialised")
	return host
end

local function finishProfile(userId: number)
	PlayerDataService.markDirty(userId)
	local saved = PlayerDataService.saveNow(userId)
	if not saved.ok then
		warn(`[Battle] save after settlement deferred for {userId}: {saved.err}`)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		PlayerDataService.push(player)
	else
		PlayerDataService.releaseIfAbsent(userId)
	end
end

local function settleRanked(record: MatchHost.Record, result: MatchRunner.EndInfo): { [number]: any }
	local rewards = {}
	for side, seat in record.seats do
		local userId = seat.userId
		if userId == nil then
			continue
		end
		local profile = PlayerDataService.getProfile(userId)
		local other = record.seats[3 - side]
		if profile == nil or other.userId == nil then
			warn(`[Battle] {record.matchId}: no profile for {userId}; not settled here`)
			continue
		end
		local r = Settlement.settle(profile, {
			matchId = record.matchId,
			opponentId = other.userId :: number,
			opponentTrophies = other.trophies or 0,
			won = result.winner == side,
			rounds = result.rounds,
			timeouts = result.timeouts[side],
			endedByForfeit = result.endedByForfeit,
			now = os.time(),
		})
		if r.ok then
			rewards[userId] = r.value
			if not r.value.duplicate and r.value.voidReason == nil then
				Quests.track(profile, "PlayRanked", 1, os.time())
				if r.value.won then
					Quests.track(profile, "WinRanked", 1, os.time())
				end
			end
			Telemetry.event(Players:GetPlayerByUserId(userId), "match_end", {
				won = result.winner == side,
				reason = result.reason,
				rounds = result.rounds,
			})
			for _, hook in endHooks do
				task.spawn(hook, userId, record, result.winner == side)
			end
		else
			warn(`[Battle] {record.matchId}: settlement refused for {userId}: {r.err}`)
		end
		finishProfile(userId)
	end
	return rewards
end

local function settleTrial(record: MatchHost.Record, result: MatchRunner.EndInfo): { [number]: any }
	local rewards = {}
	local seat = record.seats[1]
	local userId = seat.userId :: number
	local profile = PlayerDataService.getProfile(userId)
	if profile == nil then
		return rewards
	end
	local won = result.winner == 1
	if won then
		local r = Trials.grantClear(profile, record.worldId :: number, os.time())
		if r.ok then
			rewards[userId] = r.value
			Quests.track(profile, "TrialWin", 1, os.time())
			if r.value.firstClear then
				Quests.track(profile, "TrialFirstClear", 1, os.time())
			end
		end
	else
		rewards[userId] = { firstClear = false, trophies = 0, coins = 0, gems = 0 }
	end
	Telemetry.event(Players:GetPlayerByUserId(userId), "trial_end", { world = record.worldId, won = won })
	for _, hook in endHooks do
		task.spawn(hook, userId, record, won)
	end
	finishProfile(userId)
	return rewards
end

-- Starts a ranked match whose players are both on this server (profiles loaded).
function BattleService.startRanked(record: MatchHost.Record): Types.Result<nil>
	return getHost():create(record)
end

function BattleService.isInMatch(userId: number): boolean
	return host ~= nil and getHost():isInMatch(userId)
end

-- `hook(userId, record, won)` runs after each settled match (quests, telemetry).
function BattleService.onMatchEnd(hook: (userId: number, record: MatchHost.Record, won: boolean) -> ())
	table.insert(endHooks, hook)
end

function BattleService.init()
	host = MatchHost.new({
		now = function()
			return workspace:GetServerTimeNow()
		end,
		send = function(userId, push, data)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				Router.push(player, push, data)
			end
		end,
		onEnd = function(record, result)
			return if record.mode == "Ranked"
				then settleRanked(record, result)
				else settleTrial(record, result)
		end,
		reconnectSeconds = RECONNECT_SECONDS,
	})

	PlayerDataService.retainWhile(BattleService.isInMatch)

	Router.handle("Battle.Pick", function(player, args)
		return getHost():pick(player.UserId, args.round, args.action)
	end, { mutates = false, needsProfile = false })

	Router.handle("Battle.ChooseNext", function(player, args)
		return getHost():chooseNext(player.UserId, args.slot)
	end, { mutates = false, needsProfile = false })

	Router.handle("Battle.Forfeit", function(player)
		local r = getHost():forfeit(player.UserId)
		if r.ok then
			Telemetry.event(player, "battle_forfeit", {})
		end
		return r
	end, { mutates = false, needsProfile = false })

	Router.handle("Trial.Start", function(player, args, profile)
		local userId = player.UserId
		if getHost():isInMatch(userId) then
			return Result.fail("AlreadyInMatch")
		end
		local QueueCheck = BattleService.isQueued
		if QueueCheck and QueueCheck(userId) then
			return Result.fail("InQueue")
		end
		local last = lastTrial[userId]
		if last and os.clock() - last < Economy.Trials.retryCooldown then
			return Result.fail("TrialCooldown")
		end
		local prepared = Trials.prepare(profile :: any, args.worldId)
		if not prepared.ok then
			return Result.fail(prepared.err)
		end
		lastTrial[userId] = os.clock()
		local matchId = `trial-{HttpService:GenerateGUID(false)}`
		local created = getHost():create({
			matchId = matchId,
			mode = "Trial",
			worldId = args.worldId,
			seed = rng:NextInteger(1, 2_147_483_646),
			seats = {
				{ userId = userId, name = player.DisplayName, deck = prepared.value.deck },
				{ name = prepared.value.guardian.displayName, deck = prepared.value.guardian.deck },
			},
		})
		if not created.ok then
			return Result.fail(created.err)
		end
		Telemetry.event(player, "trial_start", { world = args.worldId })
		return Result.ok({ matchId = matchId })
	end, { mutates = false })

	Players.PlayerRemoving:Connect(function(player)
		getHost():disconnected(player.UserId)
		lastTrial[player.UserId] = nil
	end)
	PlayerDataService.onLoaded(function(player)
		getHost():reconnected(player.UserId)
	end)
end

-- Set by MatchmakingService so a queued player can't also start a Trial.
BattleService.isQueued = nil :: ((userId: number) -> boolean)?

function BattleService.start()
	RunService.Heartbeat:Connect(function()
		getHost():tick()
	end)
end

return BattleService
