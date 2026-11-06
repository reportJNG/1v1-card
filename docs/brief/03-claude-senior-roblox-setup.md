Claude Senior Roblox Developer Setup — 1v1 CARD
The goal is to configure Claude as a senior Roblox game development team, not just a coding assistant.

For this project, Claude needs five capabilities working together:
1. Roblox engineering: Luau, Roblox Studio, networking, DataStores, security and optimization.
2. 3D production: Character models, eggs, materials, textures, animations, VFX and environments.
3. UI/UX production: Professional Roblox interfaces, card designs, inventory, egg shop and animations.
4. World building: Terrain, architecture, lighting, level design and optimization.
5. Project intelligence: Persistent game documentation, architecture rules, coding standards, testing and memory.
One important distinction: Claude Skills provide reusable expertise and workflows; MCP servers connect Claude to external tools; plugins package integrations. You need all three, plus actual 3D creation software.
1. Essential Claude plugins and integrations
These are the integrations I would prioritize. Don't install 30 random MCP servers; build a reliable production toolchain.









1. Roblox Studio — OFFICIAL
Essential
Direct access to the actual Roblox project.

Claude can inspect the game hierarchy, create objects, edit scripts, generate meshes and materials, capture screenshots and run playtests through Studio's MCP integration.
- Roblox official Studio agent plugin
- Roblox Assistant documentation
- Install in Claude Code using /plugin and search for Roblox Studio.
  
  
  
  
  
  
  
  
  
  
  2. Blender MCP
  Essential
  Real 3D modelling and asset production.
  
  Claude can control Blender to create and modify meshes, scenes, materials, textures, lighting, rigs and animations.
- MCP for Blender — GitHub
- Windows installation:
winget install --id=astral-sh.uv -e
uvx mcp-for-blender setup


This is a community integration, not an official Blender product.










3. GitHub
Essential
Source control, PRs, issues and project history.

- Claude Code
- GitHub
  
  
  
  
  
  
  
  
  
  
  4. Context7
  Recommended
  Up-to-date technical documentation.
  
  Helps Claude reference current documentation rather than inventing Roblox API methods or using outdated examples.
- Context7 plugin listing
  
  
  
  
  
  
  
  
  
  
  5. Browser automation
  Recommended
  Web research, asset reference browsing and UI verification.
- Playwright
- Useful for testing external dashboards and web-based tooling, not a substitute for Roblox Studio playtests.

Priority order
Integration	Priority	Main purpose
Roblox Studio MCP	Essential	Build directly in Studio
Blender MCP	Essential	Create 3D assets
GitHub	Essential	Manage code
Context7	High	Documentation
Playwright	Medium	Browser testing

Important: Roblox Studio now has its own built-in MCP server. Prefer the official Roblox Studio plugin over older unofficial Studio bridges unless you have a specific missing capability. 
GitHub+1

2. Skills Claude should have
Skills are where we give Claude specialized expertise. I recommend the following structure for this game.
Skill	What Claude must be able to do
roblox-game-architect	Plan scalable Roblox architecture
roblox-luau-expert	Advanced typed Luau
roblox-studio-builder	Create and manipulate Studio objects
roblox-networking	RemoteEvents, RemoteFunctions, server authority
roblox-security	Anti-exploit and validation
roblox-performance	Mobile optimization, memory and FPS
roblox-data-persistence	DataStores, profiles and recovery
roblox-testing	Automated tests and multiplayer testing
blender-3d-modeling	Meshes, topology and modelling
3d-materials-textures	PBR materials, UVs and textures
3d-character-production	Character modelling and rigging
3d-animation-vfx	Animation, particles and effects
roblox-world-builder	Terrain and environmental creation
roblox-lighting	Lighting, atmosphere and post-processing
roblox-ui-ux	Professional Roblox interfaces
game-design-systems	Progression, economy and balance
game-card-design	Collectible cards, rarity and stats
game-qa-review	Visual and functional quality assurance

These are the skills I would create for our project, not claims that all 17 exist as ready-made official downloads.

For ready-made skills, start with:
- RoClicks Roblox development skills
- Awesome Game Development Agent Skills
- Anthropic Claude Marketplace
- GameSkill development skills
The Roblox-specific resources are especially relevant. Review their actual skill files before installing them, and avoid duplicate or conflicting instructions.
3. Professional 3D asset generation pipeline
This is particularly important for 1v1 CARD. We need Claude to produce actual usable assets, not just pretty concept images.









Blender — main 3D production software

Model eggs, character accessories, arenas, props, meshes and materials. Create UV maps, rigs and animations.
Blender official website











Substance 3D Painter — advanced texturing

Paint clean materials, metallic finishes, roughness, emissive effects and detailed textures.
Substance 3D Painter











Meshy — AI-assisted 3D generation

Generate initial meshes and textures from text or image references. Then inspect and optimize them in Blender.
Meshy











Poly Haven — asset and material library

Obtain HDRIs, textures and models with clear licensing.
Poly Haven











Mixamo — animation prototyping

Useful for initial character rigging and animation experiments. Final rigs and animations must be checked for Roblox compatibility.
Mixamo


What Claude should produce









Egg assets
12–40 unique models, rarity materials and hatch effects.









Character assets
Models, rigs, accessories and animations.









World assets
Terrain, buildings, props and environmental lighting.









Card assets
Card frames, artwork, rarity effects and 3D presentation.

My recommendation: Blender should be the main source of truth for 3D assets. AI generation is an accelerator, not a replacement for topology cleanup, UVs, rigging, optimization and visual QA.
4. Roblox engineering toolchain
These are the tools I would install alongside Claude.
Tool	Purpose	Importance
Rojo	Sync filesystem code with Studio	Essential
StyLua	Luau formatting	Essential
Luau LSP	Autocomplete and type intelligence	Essential
Selene	Static linting	High
Wally	Dependency management	High
TestEZ	Unit testing	High
Creator Hub	Official API documentation	Essential

A good development workflow:
Claude Code
    |
    +-- Roblox Studio MCP
    |      +-- Inspect game
    |      +-- Build objects
    |      +-- Generate materials
    |      +-- Playtest
    |
    +-- Blender MCP
    |      +-- Model assets
    |      +-- Materials
    |      +-- UV / Rig / Animation
    |
    +-- Rojo
    |      +-- Sync Luau
    |
    +-- StyLua + Selene + Luau LSP
    |      +-- Format
    |      +-- Lint
    |      +-- Type-check
    |
    +-- GitHub
           +-- Branches
           +-- Tests
           +-- Reviews


Roblox's own documentation explains Studio's direct MCP connection and its editing, asset generation and testing capabilities. 
GitHub+1

5. The custom skill architecture for 1v1 CARD
I would create one main orchestrator skill and specialized production skills.
.claude/
├── CLAUDE.md
│
├── skills/
│   ├── game-director/
│   │   └── SKILL.md
│   │
│   ├── roblox-architecture/
│   │   └── SKILL.md
│   ├── roblox-luau/
│   │   └── SKILL.md
│   ├── roblox-security/
│   │   └── SKILL.md
│   ├── roblox-networking/
│   │   └── SKILL.md
│   ├── roblox-performance/
│   │   └── SKILL.md
│   ├── roblox-testing/
│   │   └── SKILL.md
│   │
│   ├── 3d-asset-director/
│   │   └── SKILL.md
│   ├── blender-modeling/
│   │   └── SKILL.md
│   ├── pbr-materials/
│   │   └── SKILL.md
│   ├── character-rigging/
│   │   └── SKILL.md
│   ├── animation-vfx/
│   │   └── SKILL.md
│   │
│   ├── world-building/
│   │   └── SKILL.md
│   ├── environment-lighting/
│   │   └── SKILL.md
│   ├── roblox-ui-ux/
│   │   └── SKILL.md
│   ├── card-design/
│   │   └── SKILL.md
│   ├── economy-balancing/
│   │   └── SKILL.md
│   └── game-qa/
│       └── SKILL.md
│
└── agents/
    ├── architect.md
    ├── gameplay-engineer.md
    ├── 3d-artist.md
    ├── ui-designer.md
    ├── world-designer.md
    ├── qa-engineer.md
    └── security-reviewer.md


Each skill should contain real instructions, constraints, workflows, output specifications and quality gates. Empty skill names won't make Claude an expert.

Anthropic supports project-level skills in .claude/skills/ and project instructions in CLAUDE.md. 
Claude Platform Docs+1

6. Permanent 1v1 CARD project memory
This is what Claude should know before writing a single line of production code.

Create a root CLAUDE.md with these instructions:

# 1v1 CARD — Project Constitution

## Role
Act as a senior Roblox game development studio.
Work as a principal engineer, 3D technical artist,
UI/UX designer, game designer and QA engineer.

Do not produce rushed prototypes when production
implementation is requested.

## Game identity
A large anime-inspired collectible card battler.
Players collect characters, build 3-card decks,
fight 1v1, earn trophies, farm worlds and trade.

## Core game rules
- 100 initial characters, expandable later.
- Characters have different power levels and rarities.
- Every player starts with 5 inventory slots.
- Players can purchase more inventory capacity.
- Every battle deck contains exactly 3 cards.
- 15 shared character families.
- Matching families provide deck synergy bonuses.
- 40 planned egg types.
- Daily free egg claim.
- Eggs purchased using game currency.
- Combining 5 eggs creates an upgraded egg.
- 10 progressive farming worlds.
- Trophies unlock higher worlds.
- NPC card/item selling.
- Player-to-player trading.
- One active marketplace listing per player.
- Marketplace listings reserve their items.
- 1v1 wagers use non-cashable in-game currency.

## Battle system
- Server-authoritative matchmaking.
- Validate deck ownership and eligibility.
- Lock wagers before starting.
- Prevent duplicate settlement.
- Handle disconnects and timeouts.
- Winner receives the agreed in-game reward.
- 3D animated character battle presentation.
- Never trust client-calculated deck power or results.

## 3D asset standards
- Blender is the primary 3D production tool.
- Produce clean topology and UV maps.
- Use consistent scale and orientation.
- Optimize polygon counts and texture sizes.
- Use reusable materials and texture atlases.
- Create proper rigs and animation controllers.
- Export and validate Roblox-compatible assets.
- Every asset must have a preview and QA check.

## UI/UX standards
- Premium dark fantasy visual identity.
- Deep navy background.
- Purple, blue and gold accent colors.
- Clean anime-inspired typography.
- Consistent spacing and component geometry.
- Responsive layouts for mobile and desktop.
- Cards must be readable at small sizes.
- Clear rarity and family indicators.
- No clutter, placeholder-looking UI or random gradients.

## Engineering standards
- Strictly typed Luau where practical.
- Modular architecture.
- Server-authoritative gameplay.
- Validate every client request.
- Protect DataStores and transactions.
- Use reliable persistence and recovery.
- Avoid duplicated business logic.
- Avoid oversized scripts.
- Profile before optimizing.
- Write tests for critical gameplay systems.

## Development workflow
1. Inspect the existing project.
2. Understand the current architecture.
3. Plan the implementation.
4. Identify dependencies and risks.
5. Implement in small coherent units.
6. Run static checks and tests.
7. Open Roblox Studio and verify visually.
8. Test multiplayer and mobile behavior.
9. Review performance and security.
10. Report exactly what changed.

Never claim something works without testing it.
Never overwrite existing work without inspection.
Never create fake production functionality.



7. How to install the core setup
For your Windows development machine, I would start with:

Claude Code plugins
/plugin


Search and install:
- Roblox Studio
- Frontend Design
- Superpowers
- Code Review
- Context7

**Blender MCP**

```powershell
winget install --id=astral-sh.uv -e
uvx mcp-for-blender setup


Roblox Studio
1. Update Roblox Studio.
2. Open Assistant.
3. Open Assistant Settings.
4. Select Manage MCP Servers.
5. Enable Studio as MCP server.
6. Install the official Roblox Studio plugin in Claude Code.
7. Restart Claude Code and verify /mcp.
Skills

Create the project folder:
New-Item -ItemType Directory -Force .claude/skills
New-Item -ItemType Directory -Force .claude/agents


Put CLAUDE.md in the repository root and the specialized skills inside their respective folders.
8. Final recommended configuration
The 1v1 CARD production studio
Core
Claude Code
Architecture and orchestration
Core
Roblox Studio
Actual game development
Core
Blender
3D production
Core
GitHub
Version control
Quality
Rojo + Luau LSP
Code workflow
Quality
Selene + StyLua
Code quality
Art
Substance + Meshy
Materials and asset generation
QA
TestEZ + Studio tests
Game verification


My recommendation
I would not stop at giving Claude a list of skills. The real improvement comes from giving it a complete, tested development environment and a persistent understanding of our game.

There is also one important IP consideration: use original anime-inspired characters or properly licensed character designs rather than assuming existing anime characters can be commercially published.

The next step I recommend is building a complete downloadable Claude setup ZIP containing all 17 custom skills, the seven specialized agents, the project CLAUDE.md, installation scripts for Windows, Roblox/Blender MCP configuration and production-quality asset-generation instructions specifically for 1v1 CARD. That would turn this configuration into something you can actually install and use.