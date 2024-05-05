extends Node2D


@export var main_menu_scene_file: String

var _players: Dictionary = {}

@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var instructions_label: Label = $InstructionsLabel


func _ready() -> void:
	TestGameGlobals.player_join_signal.connect(_on_player_join)
	TestGameGlobals.player_left_signal.connect(_on_player_left)
	TestGameGlobals.return_to_main_menu_signal.connect(_on_return_to_main_menu)
	
	if MultiplayerManager.host_steam_id == MultiplayerManager.player_steam_id:
		_on_player_join(1)
		if MultiplayerManager.lobby_type == MultiplayerManager.LobbyTypes.BROKEN:
			instructions_label.text = """Simply have the client terminate their game unexpectedly. The game should crash from calling 
			"peer.disconnect_peer(player_id)" inside of MultiplayerManager._on_lobby_chat_update()
			"""
		else:
			instructions_label.text = """Have the client terminate their game. After 10 seconds of waiting, their connection should drop and the player be removed from the lobby.
			
			Optionally: Have the player terminate their game and re-join immediately. There will be 'two copies' of the player in the lobby. 
			After a few seconds, the duplicate (2nd one) will be kicked, the old one will be stuck in the lobby.
			"""
	else:
		instructions_label.text = """If the host is hosting a broken lobby, terminate the game immediately. Host should have their game crash.
		
		If the host is hosting a working lobby:
		Scenario 1: Terminate the game immediately. Host should see you drop after ~10 seconds and you can rejoin without issues.
		Scenario 2: Terminate the game immediately, and then start the game up and join the lobby again immediately again. 
		You and the host should be 'duplicated' in the lobby, and then be kicked after a few seconds when the old RPC disconnects. 
		"Old" session will remain in the game indefinitely.
		"""


func _on_player_join(id: int) -> void:
	# Only hosts spawn players in the map
	if MultiplayerManager.host_steam_id != MultiplayerManager.player_steam_id:
		return
	
	# Host will never be in this array, so no need to do - 1
	var player_index = MultiplayerManager.players.size()
	var new_player = multiplayer_spawner.spawn({
		peer_id = id, 
		player_index = player_index
	})
		
	
	if id == MultiplayerManager.host_steam_id and new_player.steam_id == "":
		new_player.steam_id = str(MultiplayerManager.host_steam_id)
	
	_players[id] = new_player


func _on_player_left(id: int) -> void:
	# If this player is in the _players array, we can clear them out and such
	if id in _players:
		_players[id].queue_free()
		_players.erase(id)


func _on_return_to_main_menu() -> void:
	MultiplayerManager.leave_lobby()
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(main_menu_scene_file)
