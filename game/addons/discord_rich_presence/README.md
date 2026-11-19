# Discord Rich Presence addon

This is the Godot 4.3 Windows-compatible pure-GDScript Discord RPC adapter.

- No GDExtension, DLL, bot token, or client secret is required.
- Uses Discord's local desktop IPC named pipe.
- Retries connection every 20 seconds if Discord is not running.
- Keeps the latest activity and reapplies it after reconnecting.
- Does nothing on unsupported platforms (including Android and headless).

The protocol implementation is adapted from SlayHorizon's
[discord-rich-presence-godot](https://github.com/SlayHorizon/discord-rich-presence-godot),
version 1.0, under the MIT license. The original copyright and license notice
are included in LICENSE.
