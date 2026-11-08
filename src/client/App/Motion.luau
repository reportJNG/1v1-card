--!strict
-- Every UI timing in one place (MISSION 10). Screens and helpers read these; reduced motion
-- (Settings) skips the decorative ones.
local Motion = {}

Motion.open = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- panels: 0.92 -> 1
Motion.openFrom = 0.92
Motion.close = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Motion.hover = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- scale 1.04
Motion.hoverScale = 1.04
Motion.press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- squash 0.94
Motion.pressScale = 0.94
Motion.spring = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.count = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- currency, power
Motion.stagger = 0.025 -- grid items, s apart
Motion.goldShineEvery = 5 -- s between shine sweeps on gold buttons
Motion.selectedPulse = 1.2 -- s, selected tile glow loop
Motion.toastHold = 2 -- s
Motion.cardLift = 1.05 -- hovered grid cards
Motion.glowBreath = 1.5 -- s, card frame glow
Motion.menuFlyIn = 1.2 -- s, main menu -> playing camera
Motion.leaving = 1 -- s, the leaving screen

return table.freeze(Motion)
