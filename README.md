# Forgotten World

A Terraria-inspired 2D sandbox RPG for Windows, with offline and online play.

## Layout
- `game/`: Godot 4 client and Windows export workflow.
- `server/`: Flask API for accounts, worlds, saves, and account moderation.
- `executor-demo/`: opt-in anti-cheat demonstration client.
- `.github/workflows/`: automated Windows build.

## Current foundation
The first milestone provides a side-view prototype (movement, generated terrain, mining and placing), a Wispbyte-ready API, persistent world metadata, and an isolated exploit-detection demo. This is a foundation, not a finished Terraria-scale game.

## Run the game
Install Godot 4.3+, import `game/project.godot`, and run the project. Controls: A/D move, Space jump, left click mine nearby terrain, right click place dirt.

## Run the API
```bash
cd server
python -m pip install -r requirements.txt
python app.py
```
Set `DATABASE_URL` for PostgreSQL in production. Local development uses SQLite if it is empty. The service binds to `0.0.0.0` and uses `PORT`.

## Wispbyte startup command
```bash
pip install -U --prefix .local -r server/requirements.txt
/usr/local/bin/python /home/container/server/app.py
```
Configure `PORT`, `SECRET_KEY`, and `DATABASE_URL` in the Wispbyte environment panel.

## Discord Rich Presence
A planned client integration will use a compatible Godot Discord RPC extension. Actual Rich Presence needs a compatible Godot Discord RPC extension and a registered Discord application ID.

## Account safety
Bans affect only Forgotten World accounts. The demo executor is opt-in and should be tested with a disposable account. It does not inspect other processes, collect credentials, modify Windows, or affect Discord accounts.


## Executor demonstration client
Run `python executor-demo/client.py` on Windows with Python 3. It uses the API URL and credentials you enter to start a 180-second demonstration. When it completes, the API permanently bans only that signed-in Forgotten World account. Test with a disposable account. The demo client is not an exploit and does not inject code into the game.
