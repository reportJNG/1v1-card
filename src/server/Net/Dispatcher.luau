--!strict
-- The request pipeline every remote goes through, kept free of Roblox objects so it is tested:
--   rate limit -> parse/validate payload -> profile loaded? -> handler (pcall) -> persist -> push
-- Handlers get a validated payload and the player's profile and return a Result. Thrown errors
-- become "ServerError"; their text is logged, never sent to the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(script.Parent.RateLimiter)

export type Reply = { ok: boolean, value: any?, err: string? }

export type Options = {
	mutates: boolean?, -- marks the profile dirty and pushes a delta on success (default true)
	saveNow: boolean?, -- saves before replying (purchases, hatches)
	needsProfile: boolean?, -- default true
}

export type Handler = (who: any, args: { [string]: any }, profile: Types.PlayerProfile?) -> Types.Result<any>

export type Deps = {
	limiter: RateLimiter.RateLimiter,
	now: () -> number,
	userIdOf: (who: any) -> number,
	getProfile: (userId: number) -> Types.PlayerProfile?,
	markDirty: (userId: number) -> (),
	saveNow: (userId: number) -> Types.Result<nil>,
	push: (who: any) -> (),
	log: (message: string) -> (),
}

local Dispatcher = {}

function Dispatcher.run(
	name: string,
	handler: Handler?,
	options: Options?,
	who: any,
	payload: unknown,
	deps: Deps
): Reply
	local def = Remotes.Requests[name]
	if def == nil or handler == nil then
		return { ok = false, err = "NotAvailable" }
	end
	if not deps.limiter:allow(who, name, def.rate, def.burst, deps.now()) then
		return { ok = false, err = "RateLimited" }
	end
	local args = def.parse(payload)
	if args == nil then
		return { ok = false, err = "BadRequest" }
	end
	local opts: Options = options or {}
	local userId = deps.userIdOf(who)
	local profile = deps.getProfile(userId)
	if profile == nil and opts.needsProfile ~= false then
		return { ok = false, err = "ProfileNotLoaded" }
	end
	local okCall, result = pcall(handler, who, args, profile)
	if not okCall then
		deps.log(`[Net] {name} error for {userId}: {result}`)
		return { ok = false, err = "ServerError" }
	end
	local r = result :: Types.Result<any>
	if not r.ok then
		return { ok = false, err = r.err }
	end
	if opts.mutates ~= false and profile then
		deps.markDirty(userId)
		if opts.saveNow then
			local saved = deps.saveNow(userId)
			if not saved.ok then
				-- The change is in memory and the autosave retries it; say so instead of failing.
				deps.log(`[Net] {name}: save deferred for {userId}: {saved.err}`)
			end
		end
		deps.push(who)
	end
	return { ok = true, value = r.value }
end

return table.freeze(Dispatcher)
