# Replica Rush

A Roblox "counterfeit fashion simulator": buy knockoff streetwear on your phone,
wait through shipping, risk a **15% customs seizure**, open your haul, and
either **wear** it or **flip it** on the ThriftLyst resale market. A seasonal
Heat Pass and daily login rewards drive people back every day.

All brand names (Gucki, Supremo, Nyke, Vittone, Prad'a, Balenciyaga, Off-Wyte,
Versachi, Chanoel, Jordann, Rolexx, Adidos...) are original parody/wordplay
names — no real trademarks are used anywhere in code or assets.

## Core loop

1. **Shop** (DupeDeal Warehouse) — spend Cash (start with $100) on a
   counterfeit item.
2. **Shipping** — every order ships for 75–210s. Progress bar in the Orders tab.
3. **Customs roll** — on delivery, a 15% chance the order is **seized**
   (item lost, small Coins consolation + push notification). Otherwise it's
   **Delivered** and the player gets an "Order Delivered" notification.
4. **Haul** — opening a delivered package plays an unboxing animation and
   reveals a random **QC grade** (Bootleg → Grade A → AAA Replica → Museum
   1:1), which sets how good it looks and what it's worth.
5. **Wear or sell** — equip it (Closet tab), list it on **ThriftLyst** at a
   price you choose (simulated buyers roll a chance to bite every ~20s based
   on how competitive your price is), or **Quick Sell** instantly for a
   guaranteed but lower payout.
6. **Heat Pass** — earn XP from opening hauls, wearing pieces, and selling.
   Free track gives small Cash/Coin drips; Premium track (unlockable with
   Robux via a Game Pass, or with grindable Coins) gives bigger payouts and
   pass-exclusive items.
7. **Daily Drop** — a 7-day escalating login streak (resets if you're gone
   more than 48h) — the single strongest lever for day-over-day retention.

## Project layout (Rojo)

```
replica-rush/
  default.project.json
  src/
    ReplicatedStorage/Shared/       -- Config, ItemData, BattlepassData, Remotes, UI theme/components
    ServerScriptService/Server/     -- all game logic (data, orders, market, battlepass, daily reward, map)
    StarterPlayer/StarterPlayerScripts/Client/  -- phone UI, notifications, unboxing, tabs
```

Everything is plain Luau — no external UI or asset dependencies required to
run and test the full loop.

## Getting it into Roblox Studio

1. Install [Rojo](https://rojo.space/) (the Studio plugin + the CLI, or use
   the [Rojo VS Code extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo)).
2. From this folder: `rojo serve` (or `rojo build -o ReplicaRush.rbxlx` to
   build a place file directly).
3. In Studio, connect the Rojo plugin to the running server (or open the
   built `.rbxlx`).
4. Hit Play. The server auto-generates the starter map, the phone UI mounts
   itself, and the whole loop (buy → ship → customs → haul → wear/sell →
   battlepass → daily reward) is playable immediately with zero extra setup.

## Before you publish

- **Game Pass**: create a "Heat Pass Premium" Game Pass in the Creator
  Dashboard and paste its id into `src/ReplicatedStorage/Shared/ProductIds.lua`.
  Until you do, the Robux unlock button tells the player it isn't configured
  yet (Coins unlock still works out of the box).
- **Art**: every catalog item in `ItemData.lua` has an `icon` placeholder
  (`rbxassetid://0`) and no real `shirtId`/`pantsId`/`accessoryId`. Wearing an
  item currently falls back to a colored proxy accessory + nameplate so the
  feature is fully testable — upload real clothing decals/meshes in Studio
  and wire the ids in for the real look.
- **Map polish**: `MapBuilder.server.lua` procedurally builds a clean,
  color-coded starter layout (plaza, DupeDeal Warehouse, ShipFast Customs
  Dock, ThriftLyst Bazaar) every time the server starts. It's a strong,
  ready-to-play base — for a truly "viral" look, keep building on top of it
  visually in Studio (terrain, trees, extra lighting/decals, a skybox).
- **DataStore**: uses a single `GetAsync`/`SetAsync` pattern with autosave +
  `BindToClose`. Fine for launch; if you scale up, consider adding
  session-locking (e.g. ProfileService) to fully protect against duping from
  multi-server edge cases.
- **Balance**: every tunable number (seizure chance, shipping time, resale
  fee, XP curve, daily reward amounts, battlepass cost) lives in
  `Shared/Config.lua` — tweak retention/monetization balance from one file.

## Why this should retain well

- **Variable-ratio reward** (QC grade roll + 15% seizure risk) is the same
  psychological hook as loot boxes/gacha — anticipation during shipping,
  payoff (or gut-punch) on delivery.
- **Daily login streak** brings players back on a schedule.
- **Asynchronous market** (ThriftLyst listings sell over real time) gives
  players a reason to check back even when not actively playing.
- **Battlepass** gives a season-long goal and a soft-currency vs. Robux
  choice, which is standard, proven Roblox monetization.
