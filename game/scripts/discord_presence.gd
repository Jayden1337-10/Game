extends Node
## Game-facing Discord Rich Presence integration.
## Configure the public Discord Application ID in Project Settings:
## discord/application_id

const RPC_SCRIPT = preload("res://addons/discord_rich_presence/discord_rich_presence.gd")

var rpc_node: Node
var session_started_at: int = 0
var current_biome := "Forest"
var current_world := "Solo World"

func _ready() -> void:
    session_started_at = int(Time.get_unix_time_from_system())
    var application_id := str(ProjectSettings.get_setting("discord/application_id", "")).strip_edges()
    if application_id.is_empty():
        return
    rpc_node = RPC_SCRIPT.new()
    rpc_node.set("app_id", application_id)
    add_child(rpc_node)
    _push_activity()

func update_presence(biome_name: String, world_name: String) -> void:
    current_biome = biome_name.strip_edges()
    current_world = world_name.strip_edges()
    if current_world.is_empty():
        current_world = "Solo World"
    _push_activity()

func _push_activity() -> void:
    if rpc_node == null:
        return
    var safe_biome := current_biome if not current_biome.is_empty() else "Unknown"
    var safe_world := current_world if not current_world.is_empty() else "Solo World"
    rpc_node.call("set_activity", {
        "details": "Exploring " + safe_biome,
        "state": "World: " + safe_world,
        "timestamps": {"start": session_started_at}
    })
