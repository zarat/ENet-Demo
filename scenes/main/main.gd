extends Node3D

@export var player_prefab: PackedScene

var multiplayer_peer = ENetMultiplayerPeer.new()
var local_player_character
var connected_peer_ids = []

func _on_host_pressed():
	$NetworkInfo/NetworkSideDisplay.text = "Server"
	multiplayer_peer.create_server(int($Menu/Port.text))
	print("Stareted server at ", $Menu/Address.text, " on port ", $Menu/Port.text)
	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo/UniquePeerID.text = str(multiplayer.get_unique_id()) # set name
	
	add_player_character(1)
	
	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			rpc("add_newly_connected_player_character", new_peer_id)
			rpc_id(new_peer_id, "add_previously_connected_player_characters", connected_peer_ids)
			add_player_character(new_peer_id)
	)
	
	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			rpc("remove_player_character_for_all", peer_id)
			remove_player_character(peer_id)
	)

func _on_join_pressed():
	$NetworkInfo/NetworkSideDisplay.text = "Client"
	$Menu.visible = false
	multiplayer_peer.create_client($Menu/Address.text, int($Menu/Port.text))
	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo/UniquePeerID.text = str(multiplayer.get_unique_id())
	print("Connected to ", $Menu/Address.text, " on port ", $Menu/Port.text)
	
# add player on server
func add_player_character(peer_id):
	connected_peer_ids.append(peer_id)
	var player_character = player_prefab.instantiate() #preload("res://prefabs/player/player.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	add_child(player_character)
	if peer_id == multiplayer.get_unique_id():
		local_player_character = player_character
	
# remove player from server
func remove_player_character(peer_id):
	connected_peer_ids.erase(peer_id)
	for child in get_children():
		if child.get_multiplayer_authority() == peer_id:
			child.queue_free()
			break
	
func _on_message_input_text_submitted(new_text):
	local_player_character.rpc("display_message", new_text)
	$MessageInput.text = ""
	$MessageInput.release_focus()
	
# add player remotely
@rpc
func add_newly_connected_player_character(new_peer_id):
	add_player_character(new_peer_id)
	
# remove player remotely
@rpc
func remove_player_character_for_all(peer_id):
	remove_player_character(peer_id)
		
# when a new player connects, add all previously connected players to its instance
@rpc
func add_previously_connected_player_characters(peer_ids):
	for peer_id in peer_ids:
		add_player_character(peer_id)

func _on_change_scene_pressed():
	if multiplayer.is_server():
		$Menu.visible = false
		# Host wählt die neue Szene aus und informiert die Clients
		var new_scene_path = "res://scenes/online_scene/online_scene.tscn"  # Pfad zur neuen Szene
		rpc("change_scene", new_scene_path)  # RPC an alle Spieler
		change_scene(new_scene_path)  # Szene lokal wechseln
	else:
		print("Only the server can initiate a scene change.")

@rpc
func change_scene(scene_path: String):
	var new_scene = load(scene_path)
	if new_scene:
		#for child in get_children():
			#child.queue_free()  # Entferne alte Knoten
		var instance = new_scene.instantiate()
		add_child(instance)
		print("Scene changed to ", scene_path)
	else:
		print("Failed to load scene: ", scene_path)
