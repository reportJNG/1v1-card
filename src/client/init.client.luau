--!strict
-- 1v1 CARD client entry point. Controllers (UI, input, presentation) are added from M5.
-- The client never decides balances, rolls, damage or results; it sends intents and renders.
local Controllers = script:FindFirstChild("Controllers")

local loaded: { any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(loaded, (require :: any)(child))
		end
	end
end
for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end
for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end
