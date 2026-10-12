# CLAUDE.md: momo-arcade conventions

A Rojo monorepo of small, cozy Roblox games (a gift for Sujan). Keep them cute, stable and asset-free.

## Tooling

- Tools are pinned in `rokit.toml` (rojo, selene, stylua, luau-lsp). Run `rokit install`.
  If a shell can't find them, prepend `~/.rokit/bin` to PATH.
- **Quality gate: `./scripts/check.sh` must print "All checks passed."** before you say a change is done.
  It runs `stylua --check`, `selene`, `rojo build` for every `games/*/default.project.json`, and
  `luau-lsp analyze` (strict type check against a Rojo sourcemap). Auto-format with `stylua shared games`.
- Never commit build output (`*.rbxl`, `*.rbxlx`) or `.cache/`; they're git-ignored.

## Hard rules

- No external HTTP, no paid assets, no Toolbox/Creator Store asset IDs. Build visuals from parts,
  materials, built-in effects (Sparkles, Smoke, ParticleEmitter with `rbxasset://textures/particles/*`),
  and UI from frames. Sounds: `rbxasset://sounds/*` only. Verify a file exists before using it:
  `ls /Applications/RobloxStudio.app/Contents/Resources/content/sounds` (only a handful exist, e.g.
  `volume_slider.ogg`, `ouch.ogg`, `oof.ogg`, `action_jump.mp3`, `action_jump_land.mp3`).
- **Server authority.** The server owns state, scoring, spawning, collisions and saving. Clients only render
  (UI, camera, sounds, particles) in response to RemoteEvents.
- RemoteEvents are server → client by default. Client → server remotes must take **no trusted arguments**,
  be rate-limited (`Shared.RateLimiter`) and validate the session's current state.
- Every tunable goes in the game's `src/shared/Config.luau`, with a comment.
- `--!strict` at the top of every Luau file. Export types from modules.

## Code conventions

- Files use `.luau`. `Name.server.luau` = Script, `Name.client.luau` = LocalScript, everything else = ModuleScript.
- Each game has one server `Main.server.luau` and one client `Main.client.luau` that just wire up modules.
- Declare RemoteEvents as static Rojo files: `src/shared/Events/<Name>.model.json` containing
  `{ "className": "RemoteEvent" }`, and expose them through a typed `Remotes.luau`. No runtime creation races.
- Round/session logic: one object per player with a `Trove` that owns its Heartbeat connection and spawned
  instances; ending a round or `Destroy()` calls `trove:Clean()`. Avoid yields inside game loops; drive
  countdowns with `Shared.Timer` ticked from Heartbeat. Guard `FireClient` with `player.Parent == Players`.
- Catch/hit detection: distance checks on Heartbeat, not `.Touched`.
- Characters: (re)attach per-character gear in `CharacterAdded`; look it up each frame rather than caching.
- DataStores: `pcall` + retries, `UpdateAsync` that **merges** (max/add deltas), save on round end,
  `PlayerRemoving` and `BindToClose`; if Studio API access is off, `warn` once and keep playing.
- Player-facing stats go to Player attributes so UI can read them without extra remotes.
- UI: built in code with `Shared.UIHelpers` (rounded pastel cards, pill buttons, `autoScale`).
  Primary buttons must be selectable for gamepad; set `GuiService.SelectedObject` when a menu opens.
- Style: tabs, 110 columns, double quotes (see `stylua.toml`). Match the comment density of existing files:
  a header block per module explaining *why*, short comments on non-obvious lines.

## Gotchas we've hit

- **Literal-union widening (old Luau solver):** `local kind = f()` where `f` returns `"A" | "B"` widens to
  `string`. Annotate the local: `local kind: Types.MomoKind = f()`.
- `pcall(fnReturningNothing)` is typed as returning only a boolean; use `table.pack(pcall(...))` if you need the error.
- DataStore calls return two values; wrap in parentheses `return (store:GetAsync(key))` inside retry helpers.
- **Two `UIScale`s on one GuiObject conflict.** `UIHelpers.autoScale` goes on a holder frame; pop/hover
  tweens (`TweenHelpers.pop`, `popIn`, button hover) use a separate "TweenScale" on the inner object.
- Children of a `UIListLayout` can't be tweened by Position; wrap them in a slot frame first.
- Cylinders lie along X. Rotate by `CFrame.Angles(0, 0, math.rad(90))` to stand them up.
- UI builder modules live under `StarterGui.<Game>Gui`. Client code requires them via
  `StarterGui:WaitForChild("<Game>Gui"):WaitForChild("<Module>")` (luau-lsp resolves these with full types)
  and builds into the `PlayerGui` clone.
- luau-lsp must run from the game folder because sourcemap paths are relative to the project file
  (`check.sh` handles this).

## Adding a new game (e.g. "Himalaya Obby", "Balance the Books")

1. Create `games/<kebab-name>/` with `src/server`, `src/client`, `src/shared`, `src/ui`.
2. Copy `games/momo-catch/default.project.json`, change `"name"` and rename the `MomoCatch` /
   `MomoCatchGui` keys to the new game's PascalCase name. Keep `"Shared": { "$path": "../../shared" }`.
3. Add `src/ui/init.meta.json` (ScreenGui, `ResetOnSpawn: false`) and `src/shared/Config.luau`,
   `Types.luau`, `Remotes.luau` + `Events/*.model.json`.
4. Put anything reusable (not game-specific) in the root `shared/` folder instead of the game.
5. `./scripts/check.sh` picks the new game up automatically (it loops over `games/*/default.project.json`).
6. Add the game to the table in `README.md` with its `rojo serve` command.
7. Each game is its own Roblox place/experience; use a distinct DataStore name in its Config.

Ideas so far: **Himalaya Obby** (pastel parkour up a mountain with prayer-flag checkpoints, tea-house
rest stops; reuse WorldBuilder-style helpers) and **Balance the Books** (a cozy stacking/balancing game
with ledgers and coins; server-owned physics like the momos).
