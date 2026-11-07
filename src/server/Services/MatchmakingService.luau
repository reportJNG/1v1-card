--!strict
-- Cross-server ranked matchmaking (design doc "Cross-server matchmaking"). The logic is in
-- Server/Matchmaking (pure, tested with mocks); this file wires it to Roblox.
--
-- Hub server (every public server):
--   Queue.Join / Queue.Leave   ticket in the MemoryStore queue (deck checked, not in a match)
--   every 2 s                  the lease holder pairs tickets (Matchmaker); every server polls
--                              its own players' tickets and teleports them when matched
--   on join                    a player with a live match (dropped within the reconnect window)
--                              is sent back to it
-- Battle server (a reserved server):
--   reads the match record by its own PrivateServerId (never teleport data), waits up to 30 s
--   for both players, rebuilds and re-validates both decks under the league level cap, runs
--   the match in BattleService and sends both players back to the Hub.
-- Studio: TeleportService doesn't work, so a pair on this server plays right here; MemoryStore
-- falls back to an in-memory map when the place is unpublished. Live servers never fall back.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Deck = require(Shared.Domain.Deck)
local Progress = require(Shared.Domain.Progress)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local MM = Server:WaitForChild("Matchmaking")
local Queue = require(MM.Queue)
local Matchmaker = require(MM.Matchmaker)
local MatchRecord = require(MM.MatchRecord)
local InMemoryMap = require(MM.InMemoryMap)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BattleService = require(script.Parent.BattleService)
local Telemetry = require(script.Parent.Telemetry)

local TICK = 2
local TICKET_TTL = 120
local REFRESH_EVERY = 30
local ACTIVE_TTL = 15 * 60
local RETURN_DELAY = 8 -- seconds on the result screen before the battle server sends players back

local MatchmakingService = {}

local queueMap: any = nil
local recordMap: any = nil
local leaseMap: any = nil
local queue: Queue.Queue? = nil
local matchmaker: Matchmaker.Matchmaker? = nil
local isBattleServer = false
local usingMemoryFallback = false
local rng = Random.new()

-- Players on this server with a ticket: userId -> { since, refreshed }
local queued: { [number]: { since: number, refreshed: number } } = {}
local startedLocal: { [string]: boolean } = {}

local function getQueue(): Queue.Queue
	assert(queue, "MatchmakingService not initialised")
	return queue
end

local function resolveMaps()
	local ok, err = pcall(function()
		local probe = MemoryStoreService:GetSortedMap("Probe")
		probe:GetAsync("probe")
	end)
	if ok then
		queueMap = MemoryStoreService:GetSortedMap("RankedQueue_v1")
		recordMap = MemoryStoreService:GetSortedMap("Matches_v1")
		leaseMap = MemoryStoreService:GetSortedMap("MatchmakerLease_v1")
		return
	end
	if not RunService:IsStudio() then
		-- Live: never fall back. Calls fail and are retried every tick; players just stay queued.
		warn(`[Matchmaking] MemoryStore unavailable: {err}`)
		queueMap = MemoryStoreService:GetSortedMap("RankedQueue_v1")
		recordMap = MemoryStoreService:GetSortedMap("Matches_v1")
		leaseMap = MemoryStoreService:GetSortedMap("MatchmakerLease_v1")
		return
	end
	usingMemoryFallback = true
	warn(
		`[Matchmaking] MemoryStore unavailable in Studio ({err}); using an in-memory queue for this server only`
	)
	local clock = setmetatable({}, {
		__index = function(_, k)
			return if k == "t" then os.clock() else nil
		end,
	}) :: any
	queueMap = InMemoryMap.new(clock)
	recordMap = InMemoryMap.new(clock)
	leaseMap = InMemoryMap.new(clock)
end

local function ascending(): any
	return if usingMemoryFallback then InMemoryMap.Ascending else Enum.SortDirection.Ascending
end

local function status(player: Player, state: string, extra: { [string]: any }?)
	local data: { [string]: any } = { state = state }
	if extra then
		for k, v in extra do
			data[k] = v
		end
	end
	Router.push(player, "Queue.Status", data)
end

local function writeRecord(record: MatchRecord.Record): boolean
	local ok = pcall(function()
		recordMap:SetAsync(`match:{record.matchId}`, record, MatchRecord.TTL)
		if record.privateServerId then
			recordMap:SetAsync(`ps:{record.privateServerId}`, record, MatchRecord.TTL)
		end
	end)
	return ok
end

local function readRecord(key: string): MatchRecord.Record?
	local ok, raw = pcall(function()
		return (recordMap:GetAsync(key))
	end)
	return if ok then MatchRecord.parse(raw) else nil
end

local function setActive(userId: number, record: MatchRecord.Record?)
	pcall(function()
		if record then
			recordMap:SetAsync(`active:{userId}`, record, ACTIVE_TTL)
		else
			recordMap:RemoveAsync(`active:{userId}`)
		end
	end)
end

-- ---------------------------------------------------------------- hub

local function seatsFor(record: MatchRecord.Record): { any }?
	local seats = {}
	for side, seat in record.seats do
		local player = Players:GetPlayerByUserId(seat.userId)
		local profile = PlayerDataService.getProfile(seat.userId)
		if player == nil or profile == nil then
			return nil
		end
		local specs = Deck.specs(profile, MatchRecord.levelCap(record))
		if not specs.ok then
			return nil
		end
		seats[side] =
			{ userId = seat.userId, name = player.DisplayName, deck = specs.value, trophies = seat.trophies }
	end
	return seats
end

local function startHere(record: MatchRecord.Record): boolean
	local seats = seatsFor(record)
	if seats == nil then
		return false
	end
	local created = BattleService.startRanked({
		matchId = record.matchId,
		mode = "Ranked",
		seed = record.seed,
		seats = seats,
	})
	return created.ok
end

local function onAssigned(player: Player, assignment: Queue.Assignment)
	local userId = player.UserId
	queued[userId] = nil
	status(player, "Found", { matchId = assignment.matchId })
	Telemetry.event(player, "queue_matched", { matchId = assignment.matchId })
	if assignment.accessCode == nil then
		-- Studio: the pair plays on this server. Start once, when the first of the two is seen.
		if not startedLocal[assignment.matchId] then
			startedLocal[assignment.matchId] = true
			local record = readRecord(`match:{assignment.matchId}`)
			if record == nil or not startHere(record) then
				for _, seat in (if record then record.seats else {}) :: { any } do
					local p = Players:GetPlayerByUserId(seat.userId)
					if p then
						status(p, "Cancelled")
					end
				end
			end
		end
		getQueue():remove(userId)
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.accessCode :: string
	-- The spot to come back to after the match (SessionService / Domain/ReturnSpot, MISSION 2.4).
	local SessionService = require(script.Parent.SessionService) :: any
	options:SetTeleportData({ returnSpot = SessionService.captureSpot(player) } :: any)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn(`[Matchmaking] teleport failed for {userId}: {err}`)
		status(player, "Cancelled")
	end
	getQueue():remove(userId)
end

local function pollLocal()
	local now = os.time()
	for userId, entry in queued do
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			queued[userId] = nil
			getQueue():leave(userId)
			continue
		end
		local got = getQueue():get(userId)
		if not got.ok then
			continue
		end
		local ticket = got.value
		if ticket == nil then
			-- Expired or removed elsewhere: put the player back to idle.
			queued[userId] = nil
			status(player, "Idle")
		elseif ticket.match then
			task.spawn(onAssigned, player, ticket.match)
		elseif now - entry.refreshed >= REFRESH_EVERY then
			entry.refreshed = now
			getQueue():refresh(userId)
		end
	end
end

local function joinQueue(player: Player, profile: any)
	local userId = player.UserId
	if isBattleServer then
		return Result.fail("NotInHub")
	end
	if queued[userId] then
		return Result.fail("AlreadyQueued")
	end
	if BattleService.isInMatch(userId) then
		return Result.fail("AlreadyInMatch")
	end
	local league = Progress.leagueFor(profile.trophies)
	local specs = Deck.specs(profile, league.rankedLevelCap)
	if not specs.ok then
		return Result.fail(specs.err)
	end
	local now = os.time()
	local joined = getQueue():join({
		userId = userId,
		trophies = profile.trophies,
		league = league.id,
		queuedAt = now,
		server = game.JobId,
	})
	if not joined.ok then
		warn(`[Matchmaking] join failed for {userId}: {joined.err}`)
		return Result.fail("QueueUnavailable")
	end
	queued[userId] = { since = now, refreshed = now }
	status(player, "Searching", { since = now, league = league.id })
	Telemetry.event(player, "queue_join", { league = league.id })
	return Result.ok({ since = now })
end

local function leaveQueue(player: Player)
	local userId = player.UserId
	if not queued[userId] then
		return Result.fail("NotQueued")
	end
	local left = getQueue():leave(userId)
	if not left.ok then
		return Result.fail("QueueUnavailable")
	end
	if left.value == "Matched" then
		return Result.fail("AlreadyMatched") -- the poll picks the assignment up
	end
	queued[userId] = nil
	status(player, "Idle")
	return Result.ok(nil)
end

local function rejoinIfActive(player: Player)
	local record = readRecord(`active:{player.UserId}`)
	if record == nil or record.accessCode == nil then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.accessCode :: string
	status(player, "Reconnecting", { matchId = record.matchId })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn(`[Matchmaking] reconnect teleport failed for {player.UserId}: {err}`)
	end
end

-- ---------------------------------------------------------------- battle server

-- Battle servers keep each player's return spot from their join data and send it back home with
-- them, so the Hub puts them where they stood before the match (validated there again).
local returnSpots: { [number]: any } = {}

local function sendHome(players: { Player })
	for _, p in players do
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ fromBattle = true, returnSpot = returnSpots[p.UserId] } :: any)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { p }, options)
		end)
		if not ok then
			warn(`[Matchmaking] return teleport failed: {err}`)
			p:Kick("The match is over. Please rejoin the game.")
		end
	end
end

local function runBattleServer()
	local function keepSpot(p: Player)
		local ok, data = pcall(function()
			return p:GetJoinData()
		end)
		local tp: any = ok and data and (data :: any).TeleportData
		if typeof(tp) == "table" and typeof(tp.returnSpot) == "table" then
			returnSpots[p.UserId] = tp.returnSpot
		end
	end
	Players.PlayerAdded:Connect(keepSpot)
	for _, p in Players:GetPlayers() do
		keepSpot(p)
	end
	local record: MatchRecord.Record? = nil
	for _ = 1, 10 do
		record = readRecord(`ps:{game.PrivateServerId}`)
		if record then
			break
		end
		task.wait(1)
	end
	if record == nil then
		warn("[Matchmaking] battle server has no match record; sending everyone home")
		sendHome(Players:GetPlayers())
		Players.PlayerAdded:Connect(function(p)
			sendHome({ p })
		end)
		return
	end
	local r = record :: MatchRecord.Record
	-- Anyone who isn't one of the two players is sent straight back.
	local function screen(p: Player)
		if MatchRecord.sideOf(r, p.UserId) == nil then
			sendHome({ p })
		end
	end
	Players.PlayerAdded:Connect(screen)
	for _, p in Players:GetPlayers() do
		screen(p)
	end
	local deadline = os.clock() + MatchRecord.ARRIVAL_SECONDS
	local seats = nil
	repeat
		task.wait(0.5)
		seats = seatsFor(r)
	until seats ~= nil or os.clock() >= deadline
	if seats == nil or not startHere(r) then
		warn(`[Matchmaking] {r.matchId} cancelled: a player didn't arrive or their deck is invalid`)
		for _, p in Players:GetPlayers() do
			status(p, "Cancelled")
		end
		task.wait(2)
		sendHome(Players:GetPlayers())
		return
	end
	for _, seat in r.seats do
		setActive(seat.userId, r)
	end
	BattleService.onMatchEnd(function(userId)
		setActive(userId, nil)
	end)
end

-- ---------------------------------------------------------------- lifecycle

-- Takes the player out of the queue, if queued (the leaving screen's reset). Already-matched
-- players are left to the normal assignment path.
function MatchmakingService.cancel(player: Player)
	if queued[player.UserId] then
		leaveQueue(player)
	end
end

function MatchmakingService.isQueued(userId: number): boolean
	return queued[userId] ~= nil
end

function MatchmakingService.init()
	resolveMaps()
	isBattleServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	queue = Queue.new(queueMap, { ttl = TICKET_TTL, ascending = ascending() })
	matchmaker = Matchmaker.new({
		queue = queue :: Queue.Queue,
		leaseStore = leaseMap,
		jobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`,
		now = os.time,
		reserve = function(): (string?, string?)
			if RunService:IsStudio() then
				return nil, nil
			end
			return TeleportService:ReserveServer(game.PlaceId)
		end,
		writeRecord = writeRecord,
		newMatchId = function()
			return `r-{HttpService:GenerateGUID(false)}`
		end,
		newSeed = function()
			return rng:NextInteger(1, 2_147_483_646)
		end,
	})
	BattleService.isQueued = MatchmakingService.isQueued

	Router.handle("Queue.Join", function(player, _args, profile)
		local SessionService = require(script.Parent.SessionService) :: any
		if not SessionService.allows(player, "queue") then
			return Result.fail("NotPlaying")
		end
		return joinQueue(player, profile)
	end, { mutates = false })
	Router.handle("Queue.Leave", function(player)
		return leaveQueue(player)
	end, { mutates = false, needsProfile = false })

	Players.PlayerRemoving:Connect(function(player)
		if queued[player.UserId] then
			queued[player.UserId] = nil
			task.spawn(function()
				getQueue():leave(player.UserId)
			end)
		end
	end)
	if not isBattleServer then
		PlayerDataService.onLoaded(function(player)
			if not BattleService.isInMatch(player.UserId) then
				rejoinIfActive(player)
			end
		end)
	end
end

function MatchmakingService.start()
	if isBattleServer then
		task.spawn(runBattleServer)
		BattleService.onMatchEnd(function(userId)
			task.delay(RETURN_DELAY, function()
				local p = Players:GetPlayerByUserId(userId)
				if p then
					sendHome({ p })
				end
			end)
		end)
		return
	end
	while true do
		task.wait(TICK)
		if next(queued) ~= nil or not usingMemoryFallback then
			local mm = matchmaker :: Matchmaker.Matchmaker
			pcall(function()
				mm:tick()
			end)
		end
		pollLocal()
	end
end

return MatchmakingService
