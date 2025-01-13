extends Node3D

var multiplayer_peer = WebSocketMultiplayerPeer.new()

const PORT = 9999
const ADDRESS = "localhost"

var connected_peer_ids = []
var local_player_character

func _on_host_pressed():
	$NetworkInfo/NetworkSideDisplay.text = "Server"
	$Menu.visible = false # host/join buttons
	$TextEdit.visible = false # server address

	# WebSocket server starten
	if not multiplayer_peer.listen(PORT, ["default"], true):
		print("Failed to start WebSocket server")
		return

	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo/UniquePeerID.text = str(multiplayer.get_unique_id()) # set name

	add_player_character(1)

	multiplayer_peer.peer_connected.connect(
		func(new_peer_id):
			await get_tree().create_timer(1).timeout
			# add the new player in all remote instances of existing players
			rpc("add_newly_connected_player_character", new_peer_id)
			# add already connected players in the instance of the new player
			rpc_id(new_peer_id, "add_previously_connected_player_characters", connected_peer_ids)
			# add the new player on the server
			add_player_character(new_peer_id)
	)

	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			# remove the player in all remote instances
			rpc("remove_player_character_for_all", peer_id)
			# remove the player on the server
			remove_player_character(peer_id)
	)

func _on_join_pressed():
	$NetworkInfo/NetworkSideDisplay.text = "Client"
	$Menu.visible = false
	$TextEdit.visible = false

	# WebSocket-Client verbinden
	if not multiplayer_peer.connect_to_url("ws://", $TextEdit.text, ":", PORT):
		print("Failed to connect to WebSocket server")
		return

	multiplayer.multiplayer_peer = multiplayer_peer
	$NetworkInfo/UniquePeerID.text = str(multiplayer.get_unique_id())

# Add player on server
func add_player_character(peer_id):
	connected_peer_ids.append(peer_id)
	var player_character = preload("res://prefabs/player/player.tscn").instantiate()
	player_character.set_multiplayer_authority(peer_id)
	add_child(player_character)
	if peer_id == multiplayer.get_unique_id():
		local_player_character = player_character

# Remove player from server
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

# Add player remotely
@rpc
func add_newly_connected_player_character(new_peer_id):
	add_player_character(new_peer_id)

# Remove player remotely
@rpc
func remove_player_character_for_all(peer_id):
	remove_player_character(peer_id)

# When a new player connects, add all previously connected players to its instance
@rpc
func add_previously_connected_player_characters(peer_ids):
	for peer_id in peer_ids:
		add_player_character(peer_id)
