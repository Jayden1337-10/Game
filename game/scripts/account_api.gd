class_name ForgottenWorldAPI
extends Node

signal api_response(path: String, status: int, data: Dictionary)

var base_url := "http://127.0.0.1:8080"
var auth_token := ""

func request_api(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_completed.bind(path, http))
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not auth_token.is_empty():
        headers.append("Authorization: Bearer " + auth_token)
    var body := JSON.stringify(payload) if not payload.is_empty() else ""
    var error := http.request(base_url.trim_suffix("/") + path, headers, method, body)
    if error != OK:
        http.queue_free()
        api_response.emit(path, 0, {"error": "Could not start HTTP request: " + str(error)})

func _on_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, path: String, http: HTTPRequest) -> void:
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    var data: Dictionary = parsed if parsed is Dictionary else {"raw": body.get_string_from_utf8()}
    api_response.emit(path, response_code, data)
    http.queue_free()

func register_account(username: String, password: String) -> void:
    request_api("/api/register", HTTPClient.METHOD_POST, {"username": username, "password": password})

func login(username: String, password: String) -> void:
    request_api("/api/login", HTTPClient.METHOD_POST, {"username": username, "password": password})

func load_profile() -> void:
    request_api("/api/profile")

func load_cosmetic_shop() -> void:
    request_api("/api/shop")

func buy_cosmetic(cosmetic_id: String) -> void:
    request_api("/api/shop/buy", HTTPClient.METHOD_POST, {"cosmetic_id": cosmetic_id})

func equip_cosmetic(cosmetic_id: String) -> void:
    request_api("/api/cosmetics/equip", HTTPClient.METHOD_POST, {"cosmetic_id": cosmetic_id})

func claim_daily_coins() -> void:
    request_api("/api/currency/daily", HTTPClient.METHOD_POST, {})

func create_world_invite(world_id: String) -> void:
    request_api("/api/worlds/" + world_id + "/invite", HTTPClient.METHOD_POST, {})

func join_world(invite_code: String) -> void:
    request_api("/api/worlds/join", HTTPClient.METHOD_POST, {"code": invite_code})

func send_world_event(world_id: String, event_data: Dictionary) -> void:
    request_api("/api/worlds/" + world_id + "/events", HTTPClient.METHOD_POST, {"event": event_data})

func poll_world_events(world_id: String, after_cursor: String = "") -> void:
    request_api("/api/worlds/" + world_id + "/events?after=" + after_cursor.uri_encode())
