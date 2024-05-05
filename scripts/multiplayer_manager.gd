extends Node

enum LobbyTypes {
	BROKEN,
	WORKING
}

const LOBBY_DATA_NAME := "name"
const LOBBY_DATA_MODE := "mode"
const LOBBY_DATA_VERSION := "version"

var lobby_id: int = 0
var lobby_type: LobbyTypes
var host_steam_id: int = 0
var peer: SteamMultiplayerPeer = null
var players := {}
var player_name: String = "Unknown Name"
var player_offline: bool = true
var player_rpc_id: int = 0
var player_steam_id: int = 0


func _ready() -> void:
	_initialize_steam()
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	Steam.run_callbacks()


func create_lobby(new_lobby_type: int = Steam.LOBBY_TYPE_PUBLIC) -> void:
	# Make sure the lobby_type is valid.
	if new_lobby_type not in [
			Steam.LOBBY_TYPE_PRIVATE, Steam.LOBBY_TYPE_FRIENDS_ONLY, 
			Steam.LOBBY_TYPE_PUBLIC, Steam.LOBBY_TYPE_INVISIBLE]:
		return
	
	if lobby_id == 0:
		if not player_offline:
			host_steam_id = Steam.getSteamID()
			print("Creating new lobby")
			_create_socket()
			Steam.createLobby(new_lobby_type, TestGameGlobals.MAX_LOBBY_COUNT)
		else:
			print("Creating offline lobby")
		
		return
	
	# Shouldn't reach here unless there's already a running lobby
	printerr(
		"Attempted to create a lobby when one (ID: %s) was already running" % lobby_id
	)


func leave_lobby() -> void:
	# If in a lobby, leave it
	if lobby_id != 0:
		# Send leave request to Steam
		Steam.leaveLobby(lobby_id)
		
		lobby_id = 0
		host_steam_id = 0
		
		# CLose the connection
		peer.close()
		peer = null
		
		players.clear()


func join_lobby(lobby_id_to_join: int) -> void:
	print("Attempting to join lobby '%s'" % lobby_id_to_join)

	# Make the lobby join request to Steam
	Steam.joinLobby(lobby_id_to_join)


@rpc("any_peer")
func register_player(new_player_name, steam_id):
	var id = multiplayer.get_remote_sender_id()
	players[id] = {"name": new_player_name, "steam_id": steam_id}
	print("Player %s connected" % players[id]["name"])
	if player_rpc_id <= 1:
		TestGameGlobals.player_join_signal.emit(id)


func unregister_player(id):
	var player = get_tree().root.find_child(str(id), true, false)
	player.rpc_label.text = "RPC: Offline"
	player.rpc_label.add_theme_color_override("font_color", Color.RED)
	var leaving_player_name: String = players[id]["name"]
	TestGameGlobals.player_left_signal.emit(id)
	players.erase(id)
	print("Player %s disconnected" % leaving_player_name)


func _connect_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	peer.create_client(steam_id, 0, [])
	multiplayer.set_multiplayer_peer(peer)
	print("Joined Steam Peer Socket")
	player_rpc_id = peer.get_unique_id()


func _create_socket():
	peer = SteamMultiplayerPeer.new()
	peer.create_host(0, [])
	multiplayer.set_multiplayer_peer(peer)
	print("Created Steam Peer Socket")
	player_rpc_id = peer.get_unique_id()


func _initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx(false, TestGameGlobals.STEAM_GAME_ID)
	print("Did Steam initialize?: %s " % initialize_response)
	if initialize_response["status"] == 0:
		player_steam_id = Steam.getSteamID()
		player_name = Steam.getPersonaName()
		player_offline = false
	# Allow the player to still play offline
	else:
		print("! Steam appears to be offline")
		player_rpc_id = 1
	
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_list_refreshed)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)


func _on_connection_failed():
	peer = null
	printerr("Connection to server failed")


func _on_connected_ok():
	print("Connection to server successful")


func _on_lobby_chat_update(_this_lobby_id: int, change_id: int, _making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)

	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
	else:
		print("%s has left the lobby." % changer_name)
		var player_id: int = 0
		for id in players:
			if players[id]["steam_id"] == change_id:
				player_id = id
				break
		var player: Player = get_tree().root.find_child(str(player_id), true, false)
		player.steam_label.text = "Steam: Offline"
		player.steam_label.add_theme_color_override("font_color", Color.RED)
		
		if host_steam_id == player_steam_id and lobby_type == LobbyTypes.BROKEN:
			peer.disconnect_peer(player_id)
			#peer.disconnect_peer(player_id, true)
			print("You SHOULD see this message, but you don't. Game crashes on the line above this.")


func _on_lobby_created(connection_result: int, new_lobby_id: int) -> void:
	if connection_result == 1:
		# Set the lobby ID
		lobby_id = new_lobby_id
		print("Created a lobby: %s" % lobby_id)

		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)

		# Set some lobby data
		Steam.setLobbyData(lobby_id, LOBBY_DATA_NAME, "Lobby Test Name")
		Steam.setLobbyData(lobby_id, LOBBY_DATA_MODE, TestGameGlobals.STEAM_DEBUG_MODE_NAME)
		Steam.setLobbyData(lobby_id, LOBBY_DATA_VERSION, TestGameGlobals.current_project_version)

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)


func _on_lobby_list_refreshed(lobbies: Array) -> void:
	var game_lobbies: Array = []
	for found_lobby_id in lobbies:
		# Pull the data about the lobby
		var lobby_name: String = Steam.getLobbyData(found_lobby_id, LOBBY_DATA_NAME)
		var lobby_mode: String = Steam.getLobbyData(found_lobby_id, LOBBY_DATA_MODE)
		var lobby_version: String = Steam.getLobbyData(found_lobby_id, LOBBY_DATA_VERSION)
		var lobby_count: int = Steam.getNumLobbyMembers(found_lobby_id)
		
		# Only worry about the 'mode' for when we don't have a steam ID set
		if lobby_mode != TestGameGlobals.STEAM_DEBUG_MODE_NAME:
			continue
		
		# Only show lobbies with the same version as this one
		if lobby_version != TestGameGlobals.current_project_version:
			continue
		
		game_lobbies.append({
			"count": lobby_count,
			"id": found_lobby_id,
			"name": lobby_name,
		})
	
	TestGameGlobals.lobby_list_loaded_signal.emit(game_lobbies)


func _on_lobby_joined(joining_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = joining_lobby_id
		if host_steam_id == 0:
			host_steam_id = Steam.getLobbyOwner(lobby_id)
			_connect_socket(host_steam_id)
	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."

		printerr("Failed to join this lobby: %s" % fail_reason)
		TestGameGlobals.return_to_main_menu_signal.emit()
	
	
func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
	printerr("Session failure with %s | Session Error %s" % [steam_id, session_error])


func _on_player_connected(id: int) -> void:
	register_player.rpc_id(id, player_name, player_steam_id)


func _on_player_disconnected(id):
	unregister_player(id)


func _on_server_disconnected():
	printerr("Server disconnected")
	if player_rpc_id > 1:
		TestGameGlobals.return_to_main_menu_signal.emit()
