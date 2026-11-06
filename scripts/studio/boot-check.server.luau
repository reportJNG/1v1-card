-- Run by run-in-roblox: starts the simulation (Run mode, no client), so the real server Script
-- boots exactly as on a live server, then checks every service started and the remotes exist,
-- and reports any error the log recorded.
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsRunning() then
	RunService:Run()
end
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
task.wait(3)
local errors = 0
for _, entry in LogService:GetLogHistory() do
	if entry.messageType == Enum.MessageType.MessageError then
		errors += 1
		print(`BOOT ERROR: {entry.message}`)
	elseif
		string.find(entry.message, "[1v1card]", 1, true) or string.find(entry.message, "[Battle]", 1, true)
	then
		print(`BOOT LOG: {entry.message}`)
	end
end
local worlds = workspace:FindFirstChild("Worlds")
local nodes, prompts = 0, 0
if worlds then
	for _, d in worlds:GetDescendants() do
		if d:GetAttribute("NodeId") then
			nodes += 1
		elseif d:IsA("ProximityPrompt") then
			prompts += 1
		end
	end
end
print(
	`BOOT CHECK: remotes={remotes and #remotes:GetChildren() or 0} worlds={worlds and #worlds:GetChildren() or 0}`
		.. ` nodes={nodes} prompts={prompts} errors={errors}`
)
