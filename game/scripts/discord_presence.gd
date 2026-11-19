extends Node
## Discord Rich Presence adapter placeholder.
## Install/configure a compatible Godot Discord RPC extension before wiring native calls.

var activity_state := "Main Menu"

func set_activity(state: String) -> void:
    activity_state = state
