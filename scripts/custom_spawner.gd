extends MultiplayerSpawner

@export var player_scene: PackedScene

@export var spawn_positions: Array[Node2D] = []

var _player_index_reference := {}

func _init() -> void:
	spawn_function = _spawn_custom


func _ready() -> void:
	if spawn_positions.size() < TestGameGlobals.MAX_LOBBY_COUNT:
		printerr(
			"Not enough spawn positions to handle a maximum lobby size!"
		)


func _spawn_custom(data: Variant) -> Node:
	# Host chooses where a player spawns in
	if MultiplayerManager.player_steam_id != MultiplayerManager.host_steam_id and \
			multiplayer.get_remote_sender_id() > 1:
		return null
	
	var node_location: Node2D = spawn_positions[data.player_index]
	_player_index_reference[data.peer_id] = data.player_index
	
	var player = player_scene.instantiate()
	player.name = str(data.peer_id)
	player.position = node_location.global_position
	
	# Interestingly, the spawned emit only calls for other players, not the host
	# As mentioned in the docs: "Only called on puppets."
	if MultiplayerManager.player_steam_id == MultiplayerManager.host_steam_id:
		spawned.emit(player)
	return player
