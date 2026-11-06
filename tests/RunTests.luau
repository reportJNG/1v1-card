--!strict
-- Runs every *.spec module under Tests/Specs with TestEZ and returns a summary plus a full
-- per-test report (one line per describe/it, with status).
-- Studio command bar:  print(require(game.ServerScriptService.Tests.RunTests)().report)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Summary = {
	passed: number,
	failed: number,
	skipped: number,
	failures: { string },
	report: string,
}

local MARK: { [string]: string } = { Success = "PASS", Failure = "FAIL", Skipped = "SKIP" }

local function walk(node: any, depth: number, lines: { string })
	for _, child in node.children do
		local phrase = child.planNode.phrase
		if child.planNode.type == "Describe" then
			table.insert(lines, `{string.rep("  ", depth)}{phrase}`)
		else
			local mark = MARK[child.status] or tostring(child.status)
			table.insert(lines, `{string.rep("  ", depth)}[{mark}] {phrase}`)
			for _, message in child.errors do
				table.insert(lines, `{string.rep("  ", depth + 2)}{message}`)
			end
		end
		walk(child, depth + 1, lines)
	end
end

return function(): Summary
	local TestEZ = (require :: any)(ReplicatedStorage:WaitForChild("DevPackages"):WaitForChild("TestEZ"))
	local specs = script.Parent:WaitForChild("Specs")
	local results = TestEZ.TestBootstrap:run({ specs }, TestEZ.Reporters.TextReporterQuiet)
	local failures = {}
	for _, message in results.errors do
		table.insert(failures, tostring(message))
	end
	local lines: { string } = {}
	walk(results, 0, lines)
	table.insert(
		lines,
		`{results.successCount} passed, {results.failureCount} failed, {results.skippedCount} skipped`
	)
	return {
		passed = results.successCount,
		failed = results.failureCount,
		skipped = results.skippedCount,
		failures = failures,
		report = table.concat(lines, "\n"),
	}
end
