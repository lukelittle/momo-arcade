# momo-arcade 🥟

A little collection of cozy Roblox games, made as a gift for Sujan.
Built with [Rojo](https://rojo.space), so all the code lives here in Git and syncs into Roblox Studio.

| Game | Folder | Status |
| --- | --- | --- |
| **Momo Catch**: catch falling momos in your steamer basket, dodge the burnt ones | [`games/momo-catch`](games/momo-catch) | Playable |
| Himalaya Obby | – | Idea |
| Balance the Books | – | Idea |

---

## Play Momo Catch in Studio (step by step)

You need: a Mac or Windows PC, [Roblox Studio](https://create.roblox.com/docs/studio/setup), and a terminal.

### 1. Install Rokit and the tools

[Rokit](https://github.com/rojo-rbx/rokit) installs the exact tool versions this repo uses (Rojo, Selene, StyLua, luau-lsp; see `rokit.toml`).

**macOS / Linux**

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

**Windows**: download the latest `rokit-*-windows-x86_64.zip` from
[Rokit releases](https://github.com/rojo-rbx/rokit/releases), unzip it, and run `rokit.exe self-install` in a terminal.

Then **open a new terminal**, go to this repo, and install the tools:

```bash
cd momo-arcade
rokit install
```

Check it worked: `rojo --version` should print `Rojo 7.7.1`.

### 2. Install the Rojo plugin in Studio

With Studio closed, run:

```bash
rojo plugin install
```

This installs the plugin that matches your Rojo version. Open Studio and you'll see **Rojo** in the **Plugins** tab.

### 3. Start the Rojo server

From the repo root:

```bash
rojo serve games/momo-catch/default.project.json
```

Leave this terminal running. It prints something like `Rojo server listening on port 34872`.

### 4. Connect from Studio and press Play

1. In Studio, create a new **Baseplate** place (or open the one you published before).
2. **Plugins** tab → **Rojo** → **Connect** (the default `localhost:34872` is right).
3. You should see `MomoCatch` folders appear in **ServerScriptService**, **ReplicatedStorage**,
   **StarterPlayer › StarterPlayerScripts**, and a `MomoCatchGui` in **StarterGui**.
4. Press **Play** (F5).

> The arena, tea house, prayer flags and mountains are **built by code when the game starts**,
> so in edit mode you'll still just see the plain Baseplate. That's expected. Press Play to see the world.

While connected, any file you save here updates in Studio straight away. Stop and press Play again to try the change.

### 5. Turn on saving (DataStore) for testing

High scores and "momos caught" are saved with DataStores. Studio blocks DataStores until you allow it:

1. **File › Publish to Roblox** (DataStores only work in a published place). Give it a name like "Momo Catch".
2. **Home › Game Settings › Security** → turn on **Enable Studio Access to API Services** → **Save**.
3. Press Play. Your best score now survives between play sessions.

If this is off, the game still works. You'll just see one yellow warning in Output saying saving is off.

### 6. Publish as a private experience and invite a friend

1. **File › Publish to Roblox** (if you haven't already).
2. Go to the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open the experience, and
   check it is **Private** (new experiences start private).
3. In Studio: **Home › Game Settings › Permissions**. Under collaborators, add your friend
   (you need to be Roblox friends) and give them **Play** permission. Save.
4. Send them the experience link from the Creator Dashboard. They can now join, and nobody else can.

> Roblox may ask you to fill in the **Maturity & Compliance questionnaire** for the experience before
> other people can join. It takes a minute in the Creator Dashboard. Menu names do move around
> between Studio versions; if something isn't where it says above, search the Studio settings for "Permissions".

### 7. Change the game: Config

Every tunable is in **[`games/momo-catch/src/shared/Config.luau`](games/momo-catch/src/shared/Config.luau)**.
Save the file while `rojo serve` is running, then stop and press Play again.

Some favourites:

| What | Setting |
| --- | --- |
| Easter-egg message | `Config.EasterEgg.Text` (and `Subtext`) |
| How many momos until the easter egg | `Config.EasterEgg.Threshold` (default 100) |
| Round length / lives | `Config.Round.LengthSeconds`, `Config.Round.StartingLives` |
| Easier or harder | `Config.Difficulty` (spawn interval and fall speed, start → end of round) |
| How rare golden / burnt momos are | `Config.Variants` |
| How forgiving catching is | `Config.Catch.Radius` |
| Colours, sounds | `Config.Colors`, `Config.Sounds` |

Tip: to see the easter egg quickly while testing, set `Threshold = 5`, play a round, then set it back.
It only ever shows **once** per player (that's saved too), so to see it again either change
`Config.Data.StoreName` (starts everyone fresh) or test with API access off.

---

## Troubleshooting

**`rojo: command not found` (or `rokit`)**
Open a new terminal so your PATH picks up `~/.rokit/bin`, then run `rokit install` from the repo folder.

**The Rojo plugin says "version mismatch" or won't connect**
Run `rojo plugin install` again (with Studio closed), then restart Studio. Make sure `rojo serve` is still
running and the plugin is using port `34872`.

**`rojo serve` says a path doesn't exist**
Run it from the repo root (the folder with `rokit.toml`). The project file links to `../../shared`.

**Connected, but the Workspace is still a plain baseplate**
That's normal: the world is built when you press Play.

**Output says `Infinite yield possible on ... MomoCatchGui`**
Rojo isn't connected or didn't sync StarterGui. Reconnect the plugin and check `StarterGui › MomoCatchGui` exists.

**There are two copies of the scripts (old + new)**
This happens if you connected Rojo to a place that already had copies pasted in. Delete the extra
`MomoCatch` folders/`MomoCatchGui` that Rojo isn't managing, or start from a fresh Baseplate.

**The Play button says "Loading…" forever**
The server couldn't finish loading save data. Look in **View › Output** for a red error from `DataService`,
and check step 5.

**Yellow warning: "Saving is off for this session"**
API access is off or the place isn't published. Harmless. See step 5 if you want saving.

**Momos are hard to see / too fast / too slow**
Tune `Config.Difficulty`. The soft circle under each of your momos (drop marker) can be turned off with
`Config.Visuals.DropMarkers = false`.

**No sound**
Check your volume and Studio's mute toggle. The game only uses Roblox's built-in sounds, so there's nothing to download.

---

## For developers

```
momo-arcade/
  rokit.toml            pinned tool versions
  selene.toml           linter config (Roblox std)
  stylua.toml           formatter config
  scripts/check.sh      runs every quality gate
  shared/               reusable Luau modules → ReplicatedStorage.Shared in every game
  games/
    momo-catch/
      default.project.json
      src/server/       → ServerScriptService.MomoCatch
      src/client/       → StarterPlayerScripts.MomoCatch
      src/shared/       → ReplicatedStorage.MomoCatch (Config, Types, Remotes, Events/)
      src/ui/           → StarterGui.MomoCatchGui (UI builder modules)
  CLAUDE.md             conventions + how to add a new game
```

Run all checks (format, lint, Rojo build, strict type check) before committing:

```bash
./scripts/check.sh
```

Auto-format: `stylua shared games`. Build a place file to open directly:
`rojo build games/momo-catch/default.project.json -o momo-catch.rbxl` (build outputs are git-ignored).
