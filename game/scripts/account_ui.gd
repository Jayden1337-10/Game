extends CanvasLayer

signal world_event_received(event: Dictionary)
signal world_loaded(data: Dictionary)

@onready var api: ForgottenWorldAPI = get_node("../AccountAPI")

var panel: PanelContainer
var username_input: LineEdit
var password_input: LineEdit
var server_input: LineEdit
var status_label: Label
var balance_label: Label
var shop_list: VBoxContainer
var world_name_input: LineEdit
var invite_input: LineEdit
var active_world_id := ""
var active_world_name := "Solo World"
var event_cursor := ""
var sync_timer: Timer
var save_elapsed := 0.0

func _ready() -> void:
    _build_ui()
    api.api_response.connect(_on_api_response)
    sync_timer = Timer.new()
    sync_timer.wait_time = 0.3
    sync_timer.timeout.connect(_sync_world)
    add_child(sync_timer)
    var config := ConfigFile.new()
    if config.load("user://account.cfg") == OK:
        api.base_url = str(config.get_value("account", "server_url", api.base_url))
        api.auth_token = str(config.get_value("account", "token", ""))
        server_input.text = api.base_url
        if not api.auth_token.is_empty():
            status_label.text = "Saved session loaded"
            api.load_profile()
            api.load_cosmetic_shop()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
        panel.visible = not panel.visible
        if panel.visible and not api.auth_token.is_empty():
            api.load_profile()
            api.load_cosmetic_shop()

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(24, 170)
    panel.custom_minimum_size = Vector2(390, 500)
    panel.visible = false
    add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(390, 500)
    panel.add_child(scroll)
    var outer := VBoxContainer.new()
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_theme_constant_override("separation", 7)
    scroll.add_child(outer)

    var heading := Label.new()
    heading.text = "FORGOTTEN WORLD ACCOUNT"
    outer.add_child(heading)
    var close_button := Button.new()
    close_button.text = "Close account panel"
    close_button.pressed.connect(func(): panel.visible = false)
    outer.add_child(close_button)

    server_input = LineEdit.new()
    server_input.placeholder_text = "API URL (https://your-wispbyte-host)"
    server_input.text = api.base_url
    outer.add_child(server_input)

    username_input = LineEdit.new()
    username_input.placeholder_text = "Username"
    outer.add_child(username_input)

    password_input = LineEdit.new()
    password_input.placeholder_text = "Password (8+ characters)"
    password_input.secret = true
    outer.add_child(password_input)

    var auth_row := HBoxContainer.new()
    outer.add_child(auth_row)
    var login_button := Button.new()
    login_button.text = "Log in"
    login_button.pressed.connect(_login)
    auth_row.add_child(login_button)
    var register_button := Button.new()
    register_button.text = "Register"
    register_button.pressed.connect(_register)
    auth_row.add_child(register_button)

    status_label = Label.new()
    status_label.text = "Press U to close this panel"
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    outer.add_child(status_label)

    balance_label = Label.new()
    balance_label.text = "Wallet: not signed in"
    outer.add_child(balance_label)

    var daily_button := Button.new()
    daily_button.text = "Claim daily 100 coins"
    daily_button.pressed.connect(func(): api.claim_daily_coins())
    outer.add_child(daily_button)

    var shop_heading := Label.new()
    shop_heading.text = "COSMETIC SHOP"
    outer.add_child(shop_heading)
    shop_list = VBoxContainer.new()
    outer.add_child(shop_list)

    var world_heading := Label.new()
    world_heading.text = "WORLD SHARING"
    outer.add_child(world_heading)
    world_name_input = LineEdit.new()
    world_name_input.placeholder_text = "New world name"
    outer.add_child(world_name_input)
    var create_button := Button.new()
    create_button.text = "Create world"
    create_button.pressed.connect(func(): _create_world())
    outer.add_child(create_button)
    invite_input = LineEdit.new()
    invite_input.placeholder_text = "Invite code"
    outer.add_child(invite_input)
    var join_button := Button.new()
    join_button.text = "Join world with invite"
    join_button.pressed.connect(func(): api.join_world(invite_input.text.strip_edges()))
    outer.add_child(join_button)

func _set_server() -> bool:
    var url := server_input.text.strip_edges().trim_suffix("/")
    if not url.begins_with("http://") and not url.begins_with("https://"):
        status_label.text = "Server URL must start with http:// or https://"
        return false
    api.base_url = url
    var config := ConfigFile.new()
    config.set_value("account", "server_url", url)
    if not api.auth_token.is_empty():
        config.set_value("account", "token", api.auth_token)
    config.save("user://account.cfg")
    return true

func _login() -> void:
    if not _set_server():
        return
    if username_input.text.strip_edges().is_empty() or password_input.text.is_empty():
        status_label.text = "Enter your username and password"
        return
    api.login(username_input.text.strip_edges(), password_input.text)

func _register() -> void:
    if not _set_server():
        return
    if username_input.text.strip_edges().is_empty() or password_input.text.length() < 8:
        status_label.text = "Choose a username and password of at least 8 characters"
        return
    api.register_account(username_input.text.strip_edges(), password_input.text)

func _create_world() -> void:
    if not _set_server():
        return
    api.create_world(world_name_input.text.strip_edges(), "dedicated")

func _on_api_response(path: String, code: int, data: Dictionary) -> void:
    if path == "/api/login" or path == "/api/register":
        if code == 200 or code == 201:
            api.auth_token = str(data.get("token", ""))
            var config := ConfigFile.new()
            config.set_value("account", "server_url", api.base_url)
            config.set_value("account", "token", api.auth_token)
            config.save("user://account.cfg")
            status_label.text = "Signed in as " + str(data.get("user", {}).get("username", "player"))
            api.load_profile()
            api.load_cosmetic_shop()
        else:
            status_label.text = str(data.get("error", "Account request failed"))
    elif path == "/api/profile":
        if code == 200:
            balance_label.text = "Wallet: %d coins" % int(data.get("coins", 0))
            var game = get_node_or_null("..")
            if game != null:
                game.coins = int(data.get("coins", 0))
                var cosmetic_names := {"forest_cape": "Forest Cape", "ember_cape": "Ember Cape", "royal_crown": "Royal Crown", "moon_halo": "Moon Halo", "slime_buddy": "Slime Buddy", "pixel_aura": "Pixel Aura"}
                game.account_owned_cosmetics.clear()
                for cosmetic_id in data.get("owned_cosmetics", []):
                    game.account_owned_cosmetics.append(cosmetic_names.get(cosmetic_id, cosmetic_id))
                game.account_equipped_cosmetic = cosmetic_names.get(str(data.get("equipped_cosmetic", "")), "None")
        else:
            status_label.text = str(data.get("error", "Could not load profile"))
    elif path == "/api/shop":
        if code == 200:
            _populate_shop(data.get("items", []))
        else:
            status_label.text = str(data.get("error", "Could not load shop"))
    elif path == "/api/currency/reward":
        if code == 200:
            status_label.text = "Enemy reward: +%d coins" % int(data.get("reward", 5))
        api.load_profile()
    elif path == "/api/currency/daily":
        status_label.text = str(data.get("error", "Daily reward claimed"))
        if code == 200:
            status_label.text = "Daily reward: +%d coins" % int(data.get("reward", 100))
        api.load_profile()
    elif path == "/api/shop/buy":
        if code == 200:
            status_label.text = "Purchase successful"
            api.equip_cosmetic(str(data.get("cosmetic_id", "")))
        else:
            status_label.text = str(data.get("error", "Purchase failed"))
        api.load_profile()
        api.load_cosmetic_shop()
    elif path == "/api/cosmetics/equip":
        status_label.text = "Cosmetic equipped" if code == 200 else str(data.get("error", "Equip failed"))
        if code == 200:
            api.load_profile()
            api.load_cosmetic_shop()
    elif path == "/api/worlds":
        if code == 201:
            active_world_id = str(data.get("id", ""))
            active_world_name = str(data.get("name", world_name_input.text.strip_edges()))
            event_cursor = ""
            sync_timer.start()
            status_label.text = "World created: " + active_world_id
            var game = get_node_or_null("..")
            if game != null:
                game.update_discord_presence()
                api.save_world(active_world_id, game._serialize_world())
            api.create_world_invite(active_world_id)
    elif path.ends_with("/invite"):
        if code == 200:
            invite_input.text = str(data.get("code", ""))
            status_label.text = "Invite code created. Share it with friends."
        else:
            status_label.text = str(data.get("error", "Invite creation failed"))
    elif path.begins_with("/api/worlds/") and path.contains("/events?after="):
        if code == 200:
            for event_data in data.get("events", []):
                if event_data is Dictionary:
                    event_cursor = str(event_data.get("created_at", event_cursor))
                    world_event_received.emit(event_data)
    elif path.begins_with("/api/worlds/") and not path.contains("/events") and data.has("data"):
        if code == 200 and data.get("data") is Dictionary:
            world_loaded.emit(data.get("data"))
    elif path == "/api/worlds/join":
        if code == 200:
            active_world_id = str(data.get("world", {}).get("id", ""))
            active_world_name = str(data.get("world", {}).get("name", "Shared World"))
            event_cursor = ""
            sync_timer.start()
            api.load_world(active_world_id)
            var game = get_node_or_null("..")
            if game != null:
                game.update_discord_presence()
            status_label.text = "Joined world " + active_world_name
        else:
            status_label.text = str(data.get("error", "Could not join world"))

func _populate_shop(items: Array) -> void:
    for child in shop_list.get_children():
        child.queue_free()
    for item in items:
        if not item is Dictionary:
            continue
        var row := HBoxContainer.new()
        var label := Label.new()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.text = "%s - %d coins%s" % [str(item.get("name", item.get("id", "Cosmetic"))), int(item.get("price", 0)), " (owned)" if item.get("owned", false) else ""]
        row.add_child(label)
        var button := Button.new()
        button.text = "Equip" if item.get("owned", false) else "Buy"
        var cosmetic_id := str(item.get("id", ""))
        if item.get("owned", false):
            button.pressed.connect(func(): api.equip_cosmetic(cosmetic_id))
        else:
            button.pressed.connect(func(): api.buy_cosmetic(cosmetic_id))
        row.add_child(button)
        shop_list.add_child(row)


func _sync_world() -> void:
    if active_world_id.is_empty() or api.auth_token.is_empty():
        return
    var game := get_node_or_null("..")
    if game == null:
        return
    var position: Vector2 = game.player_pos
    api.send_world_event(active_world_id, {"type": "player_state", "x": position.x, "y": position.y})
    api.poll_world_events(active_world_id, event_cursor)
    save_elapsed += sync_timer.wait_time
    if save_elapsed >= 5.0:
        save_elapsed = 0.0
        api.save_world(active_world_id, game._serialize_world())


func broadcast_world_event(event_data: Dictionary) -> void:
    if not active_world_id.is_empty() and not api.auth_token.is_empty():
        api.send_world_event(active_world_id, event_data)


func is_signed_in() -> bool:
    return not api.auth_token.is_empty()

func claim_enemy_reward() -> void:
    var reward_id := str(Time.get_ticks_usec()) + "-" + str(randi())
    api.claim_enemy_reward(reward_id)
