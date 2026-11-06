--!strict
-- Specs use the server's in-memory MemoryStore map (Server/Matchmaking/InMemoryMap) as their mock.
local ServerScriptService = game:GetService("ServerScriptService")
return require(ServerScriptService.Server.Matchmaking.InMemoryMap)
