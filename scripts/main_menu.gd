class_name MainMenu
extends Control

@export var lobby_list_entry_height: float = 50.0
@export var world_scene_file: String

@onready var _join_instructions: Label = %JoinLobbyInstructions
@onready var _lobby_id_form: LineEdit = %LobbyIdForm
@onready var _lobby_list: VBoxContainer = %LobbyList
@onready var _lobby_scroll_container: ScrollContainer = %LobbyScrollContainer
@onready var _refresh_button: Button = %RefreshButton

var _join_instructions_original_text = ""


func _ready() -> void:
	# Connect to the lobby list refresh signal
	TestGameGlobals.lobby_list_loaded_signal.connect(_on_lobby_list_loaded)
	
	# Load up lobby list at the start
	Steam.addRequestLobbyListStringFilter("mode", TestGameGlobals.STEAM_DEBUG_MODE_NAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	if _join_instructions != null:
		_join_instructions_original_text = _join_instructions.text


func _create_lobby_button(lobby: Dictionary) -> Button:
	var lobby_button := Button.new()
	
	lobby_button.set_text("%s\nPlayers: (%s/%s)" % [lobby["name"], lobby["count"], TestGameGlobals.MAX_LOBBY_COUNT])
	lobby_button.set_size(Vector2(_lobby_scroll_container.size.x, lobby_list_entry_height))
	lobby_button.set_name("lobby_%s" % lobby["id"])
	lobby_button.set_text_alignment(HORIZONTAL_ALIGNMENT_LEFT)
	lobby_button.connect("pressed", Callable(self, "_join_lobby").bind(lobby["id"]))
	
	return lobby_button


func _disable_join_buttons() -> void:
	_join_instructions.text = "Joining..."
	_refresh_button.set_disabled(true)
	for join_lobby_button in _lobby_list.get_children():
		join_lobby_button.set_disabled(true)
 
 
func _enable_join_buttons() -> void:
	_join_instructions.text = _join_instructions_original_text
	_refresh_button.set_disabled(false)
	for join_lobby_button in _lobby_list.get_children():
		join_lobby_button.set_disabled(false)


func _enter_lobby() -> void:
	get_tree().change_scene_to_file(world_scene_file)


func _join_lobby(lobby_id: int) -> void:
	if lobby_id != 0:
		_enter_lobby()
		MultiplayerManager.join_lobby(lobby_id)
		_disable_join_buttons()
	else:
		printerr("Invalid lobby id given, %s" % lobby_id)


func _on_create_broken_lobby_button_pressed() -> void:
	_enter_lobby()
	MultiplayerManager.lobby_type = MultiplayerManager.LobbyTypes.BROKEN
	MultiplayerManager.create_lobby(Steam.LOBBY_TYPE_PUBLIC)


func _on_working_lobby_button_pressed() -> void:
	_enter_lobby()
	MultiplayerManager.lobby_type = MultiplayerManager.LobbyTypes.WORKING
	MultiplayerManager.create_lobby(Steam.LOBBY_TYPE_PUBLIC)


func _on_join_lobby_button_pressed() -> void:
	var lobby_id: int = _lobby_id_form.text as int
	_join_lobby(lobby_id)


func _on_refresh_button_pressed() -> void:
	_refresh_button.set_disabled(true)
	for existing_lobby_button in _lobby_list.get_children():
		existing_lobby_button.queue_free()
	Steam.requestLobbyList()


func _on_lobby_list_loaded(game_lobbies: Array) -> void:
	for lobby in game_lobbies:
		# Create a button for the lobby
		_lobby_list.add_child(_create_lobby_button(lobby))
		
	_refresh_button.set_disabled(false)
