# Executor demo

Opt-in anti-cheat demonstration only. Use a disposable Forgotten World account.

1. Authenticate with that account.
2. POST to `/api/demo-exploit/start`.
3. Wait 180 seconds.
4. POST the returned `session_id` to `/api/demo-exploit/finish`.

The server then bans only that Forgotten World account and returns **HAHA GET BANNED BUDDY**. This demo does not inject into the game, inspect other processes, collect credentials, modify Windows, or affect Discord accounts.
