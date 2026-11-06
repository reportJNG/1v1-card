-- Run by run-in-roblox (see README "Tests in real Studio"): runs the TestEZ suite inside a real
-- Studio server and prints the summary.
local ServerScriptService = game:GetService("ServerScriptService")
local summary = require(ServerScriptService:WaitForChild("Tests"):WaitForChild("RunTests"))()
print(summary.report)
print(`STUDIO TESTS: {summary.passed} passed, {summary.failed} failed, {summary.skipped} skipped`)
