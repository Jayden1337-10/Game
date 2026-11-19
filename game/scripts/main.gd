extends Node2D

const TILE := 32
const WORLD_WIDTH := 180
const GRAVITY := 1100.0
const SPEED := 260.0
const JUMP := -430.0

var player_pos := Vector2(420, 260)
var velocity := Vector2.ZERO
var camera_offset := Vector2.ZERO
var blocks: Dictionary = {}
var inventory := {"grass": 0, "dirt": 24, "stone": 0}
var world_seed := 0
var status_text := "A/D move  |  SPACE jump  |  LMB mine  |  RMB place"

func _ready() -> void:
    world_seed = randi()
    _generate_world()

func _generate_world() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed
    for x in range(WORLD_WIDTH):
        var surface_y := 13 + int(round(sin(float(x) * 0.12) * 2.0 + rng.randf_range(-1.0, 1.0)))
        for y in range(surface_y, 55):
            blocks[Vector2i(x, y)] = "grass" if y == surface_y else ("dirt" if y < surface_y + 5 else "stone")

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
    queue_redraw()

func _on_ground() -> bool: return _solid(Vector2(player_pos.x, player_pos.y + 20))
func _solid(p: Vector2) -> bool: return blocks.has(Vector2i(floor(p.x / TILE), floor(p.y / TILE)))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var cell := Vector2i(floor((get_global_mouse_position().x + camera_offset.x) / TILE), floor((get_global_mouse_position().y + camera_offset.y) / TILE))
        if event.button_index == MOUSE_BUTTON_LEFT and blocks.has(cell) and Vector2(cell * TILE).distance_to(player_pos) < 150:
            var kind: String = blocks[cell]
            blocks.erase(cell)
            inventory[kind] = inventory.get(kind, 0) + 1
            status_text = "Mined " + kind
        elif event.button_index == MOUSE_BUTTON_RIGHT and not blocks.has(cell) and Vector2(cell * TILE).distance_to(player_pos) < 150 and inventory.dirt > 0:
            blocks[cell] = "dirt"
            inventory.dirt -= 1
            status_text = "Placed dirt"
        queue_redraw()

func _draw() -> void:
    var view := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, view), Color("#7896a0"))
    var left := max(0, int(camera_offset.x / TILE) - 2)
    var right := min(WORLD_WIDTH, int((camera_offset.x + view.x) / TILE) + 3)
    var top := max(0, int(camera_offset.y / TILE) - 2)
    var bottom := min(55, int((camera_offset.y + view.y) / TILE) + 3)
    for cell in blocks:
        if cell.x < left or cell.x > right or cell.y < top or cell.y > bottom: continue
        var color := Color("#4f9b45") if blocks[cell] == "grass" else (Color("#8b6546") if blocks[cell] == "dirt" else Color("#737b83"))
        var rect := Rect2(Vector2(cell * TILE) - camera_offset, Vector2(TILE, TILE))
        draw_rect(rect, color)
        draw_rect(rect, color.darkened(0.2), false, 1.0)
    var p := player_pos - camera_offset
    draw_rect(Rect2(p - Vector2(10, 24), Vector2(20, 36)), Color("#e8c18a"))
    draw_rect(Rect2(p - Vector2(11, -5), Vector2(22, 9)), Color("#463b32"))
    draw_rect(Rect2(Vector2(18, 18), Vector2(410, 94)), Color(0.04, 0.06, 0.08, 0.8))
    draw_string(ThemeDB.fallback_font, Vector2(32, 44), "FORGOTTEN WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f2e7ca"))
    draw_string(ThemeDB.fallback_font, Vector2(32, 70), "Dirt: %d   Grass: %d   Stone: %d" % [inventory.dirt, inventory.grass, inventory.stone], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(32, 96), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c8d6df"))
