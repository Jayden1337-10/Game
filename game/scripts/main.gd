extends Node2D

const TILE := 32
const WORLD_WIDTH := 420
const WORLD_HEIGHT := 80
const GRAVITY := 1100.0
const SPEED := 260.0
const JUMP := -430.0

var player_pos := Vector2(420, 260)
var velocity := Vector2.ZERO
var camera_offset := Vector2.ZERO
var blocks: Dictionary = {}
var inventory := {"grass": 0, "dirt": 24, "stone": 0, "wood": 0, "gel": 0, "copper": 0}
var equipment := {"weapon": "Wooden Sword", "head": "None", "chest": "Cloth Tunic", "legs": "None", "accessory": "None"}
var recipes := {
    "Wooden Sword": {"wood": 8},
    "Wooden Helmet": {"wood": 12},
    "Wooden Chestplate": {"wood": 20},
    "Wooden Boots": {"wood": 10},
    "Copper Blade": {"copper": 12, "wood": 4},
    "Copper Helmet": {"copper": 10},
    "Copper Chestplate": {"copper": 18},
    "Copper Boots": {"copper": 12},
    "Lucky Charm": {"copper": 6, "gel": 8}
}
var craft_names := ["Wooden Sword", "Wooden Helmet", "Wooden Chestplate", "Wooden Boots", "Copper Blade", "Copper Helmet", "Copper Chestplate", "Copper Boots", "Lucky Charm"]
var enemies: Array[Dictionary] = []
var coins := 0
var selected_slot := 0
var hotbar := ["dirt", "stone", "wood", "grass"]
var biome := "Forest"
var status_text := "A/D move | SPACE jump | LMB mine | RMB place | J attack | C craft"
var show_crafting := false
var show_inventory := false
var show_cosmetics := false
var owned_cosmetics := ["None"]
var equipped_cosmetic := "None"
var cosmetic_prices := {"Forest Cape": 35, "Royal Crown": 90, "Slime Buddy": 70}
var cosmetic_recipes := {"Leaf Crown": {"leaves": 12, "wood": 2}, "Wooden Mask": {"wood": 8}, "Slime Hat": {"gel": 6}}
var player_health := 100
var attack_cooldown := 0.0
var world_seed := 0

func _ready() -> void:
    randomize()
    world_seed = randi()
    _generate_world()
    _spawn_enemies()
    queue_redraw()

func _generate_world() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    for x in range(WORLD_WIDTH):
        var surface_y := 13 + int(round(sin(float(x) * 0.12) * 2.0 + rng.randf_range(-1.0, 1.0)))
        for y in range(surface_y, WORLD_HEIGHT):
            var kind := "grass" if y == surface_y else ("dirt" if y < surface_y + 6 else "stone")
            if y > surface_y + 8 and rng.randf() < 0.035:
                continue
            if y > surface_y + 9 and y < surface_y + 28 and rng.randf() < 0.018:
                kind = "copper"
            if x > 280 and y == surface_y:
                kind = "ash"
            blocks[Vector2i(x, y)] = kind
        if x % 37 == 8:
            _make_tree(x, surface_y - 1)
        if x % 91 == 35:
            _make_ruin(x, surface_y - 1)

func _make_tree(x: int, y: int) -> void:
    for h in range(4):
        blocks[Vector2i(x, y - h)] = "wood"
    for dx in range(-2, 3):
        for dy in range(-6, -2):
            if abs(dx) + abs(dy + 4) < 4:
                blocks[Vector2i(x + dx, y + dy)] = "leaves"

func _make_ruin(x: int, y: int) -> void:
    for dx in range(-3, 4):
        blocks[Vector2i(x + dx, y)] = "stone"
        if dx == -3 or dx == 3:
            for dy in range(1, 4):
                blocks[Vector2i(x + dx, y + dy)] = "stone"

func _spawn_enemies() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for i in range(28):
        var x := rng.randi_range(8, WORLD_WIDTH - 8)
        var ground := _surface_at(x)
        enemies.append({"pos": Vector2(x * TILE, ground * TILE - 18), "hp": 35, "speed": rng.randf_range(25.0, 55.0), "kind": "Slime"})

func _surface_at(x: int) -> int:
    for y in range(WORLD_HEIGHT):
        if blocks.has(Vector2i(x, y)):
            return y
    return 14

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("ui_left", "ui_right")
    if Input.is_key_pressed(KEY_A): direction = -1.0
    elif Input.is_key_pressed(KEY_D): direction = 1.0
    velocity.x = direction * SPEED
    velocity.y += GRAVITY * delta
    if Input.is_key_pressed(KEY_SPACE) and _on_ground(): velocity.y = JUMP
    player_pos.x += velocity.x * delta
    if _solid(Vector2(player_pos.x, player_pos.y + 18)): player_pos.x -= velocity.x * delta
    player_pos.y += velocity.y * delta
    if _solid(Vector2(player_pos.x, player_pos.y + 18)):
        if velocity.y > 0: player_pos.y = floor((player_pos.y + 18) / TILE) * TILE - 18
        velocity.y = 0
    player_pos.x = clamp(player_pos.x, 16.0, WORLD_WIDTH * TILE - 16.0)
    camera_offset = player_pos - get_viewport_rect().size / 2.0
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    _update_enemies(delta)
    var region := int(player_pos.x / TILE)
    biome = "Forest" if region < 140 else ("Mushroom Fields" if region < 280 else "Ashlands")
    queue_redraw()

func _update_enemies(delta: float) -> void:
    for enemy in enemies:
        var p: Vector2 = enemy["pos"]
        var dx := player_pos.x - p.x
        if absf(dx) < 420.0:
            p.x += signf(dx) * float(enemy["speed"]) * delta
            if absf(dx) < 28.0 and randf() < delta * 0.35:
                player_health = maxi(0, player_health - 4)
        enemy["pos"] = p

func _on_ground() -> bool:
    return _solid(Vector2(player_pos.x, player_pos.y + 20))

func _solid(p: Vector2) -> bool:
    return blocks.has(Vector2i(floori(p.x / TILE), floori(p.y / TILE)))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C: show_crafting = not show_crafting
        if event.keycode == KEY_I: show_inventory = not show_inventory
        if event.keycode == KEY_M: show_cosmetics = not show_cosmetics
        if show_crafting and event.keycode >= KEY_1 and event.keycode <= KEY_5:
            _craft(craft_names[event.keycode - KEY_1])
        if show_cosmetics and event.keycode >= KEY_1 and event.keycode <= KEY_3:
            _craft_cosmetic(["Leaf Crown", "Wooden Mask", "Slime Hat"][event.keycode - KEY_1])
        elif show_cosmetics and event.keycode >= KEY_4 and event.keycode <= KEY_6:
            _buy_cosmetic(["Forest Cape", "Royal Crown", "Slime Buddy"][event.keycode - KEY_4])
        if event.keycode >= KEY_1 and event.keycode <= KEY_4: selected_slot = event.keycode - KEY_1
        if event.keycode == KEY_J: _attack()
        if event.keycode == KEY_E: _equip_best()
    if event is InputEventMouseButton and event.pressed:
        var world_mouse := get_global_mouse_position() + camera_offset
        var cell := Vector2i(floori(world_mouse.x / TILE), floori(world_mouse.y / TILE))
        if event.button_index == MOUSE_BUTTON_LEFT:
            if blocks.has(cell) and Vector2(cell * TILE).distance_to(player_pos) < 150.0:
                var kind: String = blocks[cell]
                blocks.erase(cell)
                inventory[kind] = inventory.get(kind, 0) + 1
                if kind == "wood": coins += 1
                status_text = "Mined " + kind
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            var kind: String = hotbar[selected_slot]
            if not blocks.has(cell) and Vector2(cell * TILE).distance_to(player_pos) < 150.0 and inventory.get(kind, 0) > 0:
                blocks[cell] = kind
                inventory[kind] -= 1
                status_text = "Placed " + kind
        queue_redraw()

func _attack() -> void:
    if attack_cooldown > 0.0: return
    attack_cooldown = 0.45
    var damage := 22 if equipment["weapon"] == "Wooden Sword" else (38 if equipment["weapon"] == "Copper Blade" else 8)
    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Dictionary = enemies[i]
        if Vector2(enemy["pos"]).distance_to(player_pos) < 76.0:
            enemy["hp"] = int(enemy["hp"]) - damage
            if enemy["hp"] <= 0:
                enemies.remove_at(i)
                inventory["gel"] += 1
                coins += 5
            else:
                enemies[i] = enemy
            break

func _craft(item: String) -> void:
    if not recipes.has(item): return
    var cost: Dictionary = recipes[item]
    for material in cost:
        if inventory.get(material, 0) < cost[material]:
            status_text = "Not enough " + material
            return
    for material in cost:
        inventory[material] -= cost[material]
    if item == "Wooden Sword" or item == "Copper Blade":
        equipment["weapon"] = item
    elif item.ends_with("Helmet"):
        equipment["head"] = item
    elif item.ends_with("Chestplate"):
        equipment["chest"] = item
    elif item.ends_with("Boots"):
        equipment["legs"] = item
    elif item == "Lucky Charm":
        equipment["accessory"] = item
    status_text = "Crafted " + item

func _craft_cosmetic(item: String) -> void:
    var cost: Dictionary = cosmetic_recipes[item]
    for material in cost:
        if inventory.get(material, 0) < cost[material]:
            status_text = "Need more " + material
            return
    for material in cost: inventory[material] -= cost[material]
    owned_cosmetics.append(item)
    equipped_cosmetic = item
    status_text = "Made and equipped " + item

func _buy_cosmetic(item: String) -> void:
    if item in owned_cosmetics:
        equipped_cosmetic = item
        status_text = "Equipped " + item
        return
    var price: int = cosmetic_prices[item]
    if coins < price:
        status_text = "Need %d more coins" % (price - coins)
        return
    coins -= price
    owned_cosmetics.append(item)
    equipped_cosmetic = item
    status_text = "Bought " + item

func _equip_best() -> void:
    if inventory.get("copper", 0) >= 12:
        _craft("Copper Blade")
    elif inventory.get("wood", 0) >= 8:
        _craft("Wooden Sword")

func _draw() -> void:
    var view := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, view), Color("#7896a0"))
    var left := max(0, int(camera_offset.x / TILE) - 2)
    var right := min(WORLD_WIDTH, int((camera_offset.x + view.x) / TILE) + 3)
    var top := max(0, int(camera_offset.y / TILE) - 2)
    var bottom := min(WORLD_HEIGHT, int((camera_offset.y + view.y) / TILE) + 3)
    for cell in blocks:
        if cell.x < left or cell.x > right or cell.y < top or cell.y > bottom: continue
        var kind: String = blocks[cell]
        var color := Color("#4f9b45")
        if kind == "dirt": color = Color("#8b6546")
        elif kind == "stone": color = Color("#737b83")
        elif kind == "wood": color = Color("#76502e")
        elif kind == "leaves": color = Color("#347747")
        elif kind == "copper": color = Color("#b86d43")
        elif kind == "ash": color = Color("#655d68")
        var rect := Rect2(Vector2(cell * TILE) - camera_offset, Vector2(TILE, TILE))
        draw_rect(rect, color)
        draw_rect(rect, color.darkened(0.2), false, 1.0)
    for enemy in enemies:
        var ep: Vector2 = enemy["pos"] - camera_offset
        draw_rect(Rect2(ep - Vector2(13, 12), Vector2(26, 24)), Color("#65c95c"))
        draw_rect(Rect2(ep - Vector2(7, 3), Vector2(4, 4)), Color("#17251b"))
        draw_rect(Rect2(ep + Vector2(3, -3), Vector2(4, 4)), Color("#17251b"))
    var p := player_pos - camera_offset
    draw_rect(Rect2(p - Vector2(10, 24), Vector2(20, 36)), Color("#e8c18a"))
    if equipped_cosmetic.find("Cape") >= 0:
        draw_rect(Rect2(p + Vector2(-14, -12), Vector2(7, 30)), Color("#397a55"))
    elif equipped_cosmetic.find("Crown") >= 0 or equipped_cosmetic.find("Hat") >= 0:
        draw_rect(Rect2(p + Vector2(-8, -29), Vector2(16, 6)), Color("#d9b34f"))
    elif equipped_cosmetic == "Slime Buddy":
        draw_rect(Rect2(p + Vector2(18, 2), Vector2(13, 12)), Color("#65c95c"))
    draw_rect(Rect2(p - Vector2(11, -5), Vector2(22, 9)), Color("#463b32"))
    draw_rect(Rect2(Vector2(18, 18), Vector2(510, 140)), Color(0.04, 0.06, 0.08, 0.82))
    draw_string(ThemeDB.fallback_font, Vector2(32, 44), "FORGOTTEN WORLD  |  " + biome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f2e7ca"))
    draw_string(ThemeDB.fallback_font, Vector2(32, 70), "HP %d   Coins %d   Weapon: %s" % [player_health, coins, equipment["weapon"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(32, 96), "Dirt %d  Stone %d  Wood %d  Copper %d  Gel %d" % [inventory.dirt, inventory.stone, inventory.wood, inventory.copper, inventory.gel], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d5dfdc"))
    draw_string(ThemeDB.fallback_font, Vector2(32, 122), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c8d6df"))
    draw_string(ThemeDB.fallback_font, Vector2(32, 145), "Cosmetic: " + equipped_cosmetic + " | C craft | I inventory | M cosmetics", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f0d59b"))
    for i in range(hotbar.size()):
        var x := 32 + i * 48
        draw_rect(Rect2(Vector2(x, view.y - 66), Vector2(42, 42)), Color("#3a4146") if i != selected_slot else Color("#d2ae61"))
        draw_string(ThemeDB.fallback_font, Vector2(x + 8, view.y - 39), str(inventory.get(hotbar[i], 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
    if show_crafting:
        draw_rect(Rect2(Vector2(550, 100), Vector2(360, 240)), Color("#171d20"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 130), "CRAFTING (press C to close)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f2e7ca"))
        for i in range(craft_names.size()):
            draw_string(ThemeDB.fallback_font, Vector2(570, 164 + i * 30), "%d. %s" % [i + 1, craft_names[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 320), "Press 1-5 to craft while this panel is open", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c8d6df"))
    if show_cosmetics:
        draw_rect(Rect2(Vector2(550, 100), Vector2(390, 270)), Color("#171d20"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 130), "COSMETIC STALL (M to close)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f2e7ca"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 164), "1 Leaf Crown: craft (12 leaves, 2 wood)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 190), "2 Wooden Mask: craft (8 wood)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 216), "3 Slime Hat: craft (6 gel)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 250), "4 Forest Cape: buy (35 coins)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d6c18d"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 276), "5 Royal Crown: buy (90 coins)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d6c18d"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 302), "6 Slime Buddy: buy (70 coins)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d6c18d"))
    if show_inventory:
        draw_rect(Rect2(Vector2(550, 360), Vector2(360, 150)), Color("#171d20"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 390), "EQUIPMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f2e7ca"))
        draw_string(ThemeDB.fallback_font, Vector2(570, 420), "Weapon: " + equipment["weapon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 446), "Head: " + equipment["head"] + " | Chest: " + equipment["chest"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(570, 472), "Legs: " + equipment["legs"] + " | Accessory: " + equipment["accessory"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
