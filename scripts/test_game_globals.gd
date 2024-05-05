extends Node

const STEAM_GAME_ID = 480

## Just to be able to know which lobby belongs to this game during debug stages
const STEAM_DEBUG_MODE_NAME = "U01QVGVzdEdhbWVNb2RlCg=="

const MAX_LOBBY_COUNT = 4

var current_project_version: String = ProjectSettings.get_setting("application/config/version")

# Signals

signal lobby_list_loaded_signal(results: Array[Dictionary])
signal player_left_signal(id: int)
signal player_join_signal(id: int)
signal return_to_main_menu_signal()
