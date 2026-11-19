# Forgotten World

A Terraria-inspired 2D sandbox RPG prototype built with Godot 4 and a Flask account/world service.

## Repository
- `game/`: Godot client.
- `server/`: Flask API, SQLite/PostgreSQL persistence and automated tests.
- `executor-demo/`: opt-in account-scoped moderation demonstration.
- `.github/workflows/`: backend regression tests and Windows export checks.

## Gameplay
- Six procedural biomes: Forest, Mushroom Fields, Crystal Caverns, Frostreach, Ashlands and Sunken Ruins.
- Biome-specific terrain and resources, including crystals, ice, snow, sand, herbs and ancient relics.
- Distinct crystal formations, frost trees, mushroom growths and ancient brick ruins with collectible relic caches.
- Slime, Fungus, Ash Slime, Crystal Mote, Frost Wisp and Sand Beetle creatures.
- Exploration journal with gathering and discovery quests that award local coins.
- Movement, jumping, mining, block placement, a four-slot hotbar, inventory and crafting.
- Local cosmetics: craftable Leaf Crown, Wooden Mask and Slime Hat; Forest Cape, Royal Crown and Slime Buddy.
- Local world autosave every 30 seconds to `user://world_save.json`.
- Remote player display and tile-change relay in shared worlds.

## Controls
- A/D or arrow keys: move.
- Space: jump.
- Left click: mine nearby blocks.
- Right click: place the selected hotbar block.
- 1-4: select hotbar slot.
- C: crafting panel; use 1-9 to craft.
- I: equipment panel.
- M: local cosmetic crafting stall.
- Q: adventurer journal and quest progress.
- U: account, persistent wallet, online cosmetic shop and world-sharing panel.

## Run the account server
Local development:
```bash
cd server
python -m pip install -r requirements.txt
python app.py
```
The local default uses SQLite. For production, set `DATABASE_URL` to PostgreSQL, set a long random `SECRET_KEY`, and set `CORS_ORIGINS` to the origins you actually need.

Wispbyte startup command:
```bash
pip install -U --prefix .local -r server/requirements.txt
/usr/local/bin/python /home/container/server/app.py
```
Set `PORT`, `SECRET_KEY`, and `DATABASE_URL` in the Wispbyte environment panel. The application initializes its schema on import, so Gunicorn can also load `app:app` from the server directory.

## Accounts and persistent economy
- Register and log in from the in-game panel (U).
- The session token and server URL are saved locally in `user://account.cfg`.
- `GET /api/profile`: wallet balance, owned cosmetics and equipped cosmetic.
- `GET /api/shop`: catalogue with current ownership.
- `POST /api/shop/buy`: atomic, server-validated cosmetic purchase.
- `POST /api/cosmetics/equip`: equip an owned cosmetic.
- `POST /api/currency/daily`: claim 100 coins once per UTC day.
- `POST /api/currency/reward`: claim a fixed 5-coin slime defeat reward, with duplicate protection and a 200-coin daily gameplay reward cap.

Online enemy rewards update the account wallet; offline play uses the local save's coin balance. The online shop is persistent and separate from the local crafting stall.

## Shared worlds
- Create a world and invite code in the in-game U panel.
- Friends register/log in, enter the invite code and join.
- The client relays player positions and block edits, and periodically uploads a compact world snapshot.
- World data and memberships are stored by the server.

This is a small polling-based multiplayer prototype, not a production authoritative game server. Enemy health, combat outcomes, and anti-cheat validation are not yet authoritative or synchronised. Avoid treating it as secure against modified clients.

## Automated checks
- Backend tests cover registration/login, auth requirements, daily currency, capped rewards, cosmetic purchases/equipping, world invites, shared saves and event delivery.
- GitHub Actions runs the backend tests and a Godot Windows export check on pushes.
- A successful backend test run has been observed. The Windows export must complete successfully before a tested executable can be claimed.

## Discord Rich Presence

The game includes a pure-GDScript Discord RPC adapter at
`game/addons/discord_rich_presence/`. It uses the Discord desktop app's
local IPC connection; it does not use a bot token, client secret, external
service, or native DLL.

On Windows desktop, Rich Presence shows the current biome, active shared-world
name (or "Solo World"), and the session start time. It retries if Discord is
closed and reapplies the latest activity after reconnecting. Unsupported
platforms (including Android and headless builds) safely do nothing.

### Configure Discord Rich Presence

1. Open the [Discord Developer Portal](https://discord.com/developers/applications).
2. Create a new application and copy its **Application ID**. This is a public
   numeric ID. Do not use a bot token or client secret.
3. Open `game/project.godot`.
4. Under `[discord]`, replace the empty value:
   ```ini
   [discord]
   enabled=true
   application_id="YOUR_NUMERIC_APPLICATION_ID"
   ```
5. Run the Windows desktop game while the Discord desktop app is running.

No image assets are required. If you want a quick opt-out, set
`enabled=false`. The game does not publish account names, invite codes,
chat messages, or authentication details to Discord.

## Demo client
The opt-in demo client affects only the Forgotten World account signed into it. It does not inject into processes, inspect other programs, modify Windows or affect Discord. Use a disposable test account.
