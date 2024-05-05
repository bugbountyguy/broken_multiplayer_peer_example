class_name Player
extends Node2D

var steam_id: int

@onready var steam_label: Label = $SteamLabel
@onready var rpc_label: Label = $RPCLabel


func _ready() -> void:
	if MultiplayerManager.peer != null:
		rpc_label.add_theme_color_override("font_color", Color.GREEN)
		rpc_label.text = "RPC: Online"
	else:
		rpc_label.add_theme_color_override("font_color", Color.RED)
		rpc_label.text = "RPC: Offline"
	
	if MultiplayerManager.player_steam_id > 0:
		steam_label.add_theme_color_override("font_color", Color.GREEN)
		steam_label.text = "Steam: Online"
	else:
		steam_label.add_theme_color_override("font_color", Color.RED)
		steam_label.text = "Steam: Offline"
