# Forgotten World

A Terraria-inspired 2D sandbox RPG prototype for Windows, with offline gameplay and a Wispbyte-ready account/world service.

## Repository layout
- `game/`: Godot 4 client.
- `server/`: Flask API for accounts, worlds, currency, cosmetics and multiplayer event relay.
- `executor-demo/`: opt-in account-scoped moderation demonstration.
- `.github/workflows/`: automated Windows build workflow.

## Current game prototype
- Procedurally generated side-scrolling world with Forest, Mushroom Fields and Ashlands regions, underground caves, copper ore, trees and stone ruins.
- Pixel-style terrain and character rendering using crisp geometric shapes.
- Movement, jumping, mining, block placement and a four-slot hotbar.
- Slime enemies, basic contact damage, melee attacks, health and coin drops.
- Inventory materials, wooden/copper weapons, basic armor recipes and crafting panel.
- Cosmetic stall: craft Leaf Crown, Wooden Mask and Slime Hat, or buy Forest Cape, Royal Crown and Slime Buddy with coins.
- Basic cosmetic visuals on the player.

## Controls
- A/D or arrow keys: move
- Space: jump
- Left click: mine nearby blocks
- Right click: place the selected hotbar block
- 1-4: select hotbar slot
- J: melee attack
- C: crafting panel; use 1-5 to craft
- I: equipment panel
- M: cosmetic stall; 1-3 craft cosmetics and 4-6 buy cosmetics

## Account API and economy
Run the API locally:
```bash
cd server
python -m pip install -r requirements.txt
python app.py
```
Set `DATABASE_URL` for PostgreSQL in production. Local development uses SQLite if it is empty. Set a strong `SECRET_KEY` and restrict `CORS_ORIGINS` before public deployment.

Wispbyte startup command:
```bash
pip install -U --prefix .local -r server/requirements.txt
/usr/local/bin/python /home/container/server/app.py
```
Configure `PORT`, `SECRET_KEY`, and `DATABASE_URL` in the Wispbyte environment panel.

Economy endpoints:
- `GET /api/profile`: coin balance, owned cosmetics and equipped cosmetic.
- `GET /api/shop`: cosmetic catalogue and prices.
- `POST /api/shop/buy`: server-validated cosmetic purchase.
- `POST /api/cosmetics/equip`: equip a cosmetic the account owns.
- `POST /api/currency/daily`: claim 100 coins once per UTC day.

The game-side cosmetic stall is currently a local prototype economy; the Godot API client exposes the persistent account/shop methods, but the login and shop UI still need to be connected to it. Server-side purchases and balances are authoritative when using the API.

## World sharing and multiplayer foundation
- Owners can create invite codes at `POST /api/worlds/<world_id>/invite`.
- Players join with `POST /api/worlds/join` and the invite code.
- Members can send and poll small world events at `/api/worlds/<world_id>/events`.
- `game/scripts/account_api.gd` provides Godot request helpers for login, profile, shop, invites and event polling.

This is a polling-based event relay foundation, not finished real-time multiplayer. The client does not yet automatically replicate player movement, combat, block changes or enemy state, and dedicated server authority/anti-cheat still needs implementation.

## Discord Rich Presence
A compatible Godot Discord RPC extension and a registered Discord application ID are still required. The current presence script remains a stub.

## Build status
Open `game/project.godot` in Godot 4.3+. The Windows export workflow is configured but must pass a real GitHub Actions build before the executable can be considered tested. GDScript has not yet been compiled in the Godot editor in this environment.

## Account safety
The opt-in demo client only targets the Forgotten World account signed into it. It does not inject into processes, inspect other programs, modify Windows or affect Discord accounts. Use a disposable test account.
