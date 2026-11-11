--!strict
-- Player-facing description of a Special, written from its real numbers in Config/Characters (the
-- same fields the battle engine reads), so the text can never drift from the rules. Pure.
local Types = require(script.Parent.Parent.Types)

local AbilityText = {}

local function pct(f: number): string
	return `{math.floor(f * 100 + 0.5)}%`
end

local STATUS_TEXT: { [string]: string } = {
	Burn = "Burn",
	Chill = "Chill",
	Weaken = "Weaken",
	Shield = "a shield",
	Reflect = "Reflect",
}

-- The Special's main effect in one short line ("Deals 1.33x ATK damage."), for the Cards inspect
-- panel where only one big line fits (BAD_GUI_9 section 3); the full text is in the stats panel.
function AbilityText.short(a: Types.AbilityDef): string
	local full = AbilityText.special(a)
	local first = string.match(full, "^([^,]+),") or string.sub(full, 1, -2)
	return first .. "."
end

function AbilityText.special(a: Types.AbilityDef): string
	local parts: { string } = {}
	if a.kind == "Damage" then
		table.insert(parts, `Deals {string.format("%.2f", a.multiplier or 1)}x ATK damage`)
	elseif a.kind == "Heal" then
		table.insert(parts, `Heals {pct(a.healFraction or 0)} of max HP`)
	elseif a.kind == "Shield" then
		table.insert(parts, `Gains a shield worth {pct(a.shieldFraction or 0)} of max HP`)
	elseif a.kind == "Stance" then
		local s = `Blocks {pct(a.blockFraction or 0)} of the next hit this round`
		if a.reflectFraction and a.reflectFraction > 0 then
			s ..= ` and reflects {pct(a.reflectFraction)}`
		end
		table.insert(parts, s)
	end
	if a.priority then
		table.insert(parts, "acts first")
	end
	if a.pierceGuard and a.pierceGuard > 0 then
		table.insert(parts, `ignores {pct(a.pierceGuard)} of Defend`)
	end
	if a.armorPen and a.armorPen > 0 then
		table.insert(parts, `ignores {pct(a.armorPen)} of DEF`)
	end
	if a.cleanse then
		table.insert(parts, "removes your bad effects")
	end
	local applies: { Types.StatusApplication } = a.applies or {}
	for _, ap in applies do
		local who = if ap.target == "Self" then "you" else "the opponent"
		table.insert(
			parts,
			`gives {who} {STATUS_TEXT[ap.status] or ap.status} for {ap.rounds} round{if ap.rounds == 1
				then ""
				else "s"}`
		)
	end
	if a.recoilFraction and a.recoilFraction > 0 then
		table.insert(parts, `costs {pct(a.recoilFraction)} of your max HP`)
	end
	return table.concat(parts, ", ") .. "."
end

return table.freeze(AbilityText)
