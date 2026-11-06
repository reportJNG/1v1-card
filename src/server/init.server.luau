--!strict
-- 1v1 CARD server entry point.
-- 1. Validate all content config; refuse to start if it is invalid.
-- 2. init() every service, then start() every service that has one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigValidator = require(Shared.Domain.ConfigValidator)

local report = ConfigValidator.validate({ release = not RunService:IsStudio() })
for _, message in report.warnings do
	warn(`[Config] {message}`)
end
if #report.errors > 0 then
	for _, message in report.errors do
		warn(`[Config] ERROR {message}`)
	end
	error(`[1v1card] {#report.errors} config error(s); server will not start`)
end

local Services = script:WaitForChild("Services")
local ORDER = { "PolicyGate", "PlayerDataService", "PurchaseService", "PolicySelfCheck" } -- explicit dependency order; append new services here

local loaded: { any } = {}
for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), `missing service {name}`)
	table.insert(loaded, (require :: any)(module))
end
for _, service in loaded do
	if typeof(service.init) == "function" then
		service.init()
	end
end
for _, service in loaded do
	if typeof(service.start) == "function" then
		task.spawn(service.start)
	end
end

print(`[1v1card] server started ({#report.warnings} launch warnings)`)
