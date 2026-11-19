extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
    var main_script = load("res://scripts/main.gd")
    if main_script == null:
        push_error("Main gameplay script failed to load")
        quit(1)
        return
    var account_script = load("res://scripts/account_ui.gd")
    if account_script == null:
        push_error("Account UI script failed to load")
        quit(1)
        return
    var packed = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Main scene failed to load")
        quit(1)
        return
    var instance = packed.instantiate()
    root.add_child(instance)
    await process_frame
    if instance.get_node_or_null("AccountAPI") == null or instance.get_node_or_null("AccountUI") == null:
        push_error("Required account nodes are missing")
        quit(1)
        return
    if not instance.has_method("_serialize_world") or not instance.has_method("_apply_shared_world"):
        push_error("World persistence or shared-world handlers are missing")
        quit(1)
        return
    var snapshot: Dictionary = instance._serialize_world()
    if not snapshot.has("seed") or not snapshot.has("blocks"):
        push_error("World snapshot is incomplete")
        quit(1)
        return
    print("Forgotten World smoke test passed")
    quit(0)
