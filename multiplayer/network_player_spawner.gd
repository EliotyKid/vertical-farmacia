class_name NetworkPlayerSpawner
extends Node

@export var player_scene: PackedScene
@export var host_spawn: Node3D
@export var client_spawn: Node3D
@export var client_spawn_2: Node3D
@export var client_spawn_3: Node3D

const PLAYER_COLORS: Array[Color] = [
	Color("2e5985"),
	Color("e06133"),
	Color("49a66f"),
	Color("9b68d8"),
]

var _network_session: Node
var _local_player: PharmacyPlayer
var _remote_players: Dictionary = {}
var _roster_size: int = 0
var _local_slot_assigned: bool = false

func _ready() -> void:
	_local_player = get_tree().get_first_node_in_group("player") as PharmacyPlayer
	_network_session = get_node_or_null("/root/NetworkSession")
	if _network_session == null or _local_player == null:
		return
	_network_session.session_started.connect(_on_session_started)
	_network_session.session_ended.connect(_on_session_ended)
	_network_session.peer_list_changed.connect(_on_peer_list_changed)
	_network_session.peer_identity_changed.connect(_on_peer_identity_changed)
	_network_session.player_state_received.connect(_on_player_state_received)

func _process(_delta: float) -> void:
	if _network_session == null or _local_player == null:
		return
	if not _local_player.is_network_session_active:
		return
	_local_player.network_send_accumulator += _delta
	if _local_player.network_send_accumulator < _local_player.network_send_interval:
		return
	_local_player.network_send_accumulator = 0.0
	_network_session.submit_local_player_state(
		_local_player.global_position,
		_local_player.rotation.y,
		_local_player.head.rotation.x
	)

func _on_session_started(local_peer_id: int, host: bool) -> void:
	_roster_size = 1
	_local_slot_assigned = host
	var local_name := str(_network_session.peer_names.get(local_peer_id, "Jogador local"))
	_local_player.configure_network_player(local_peer_id, true, local_name)
	var spawn := host_spawn if host else client_spawn
	if spawn != null:
		_local_player.global_transform = spawn.global_transform
		_local_player.set_safe_transform(spawn.global_transform)
	_on_peer_list_changed(_network_session.connected_peer_ids)

func _on_session_ended() -> void:
	for player: PharmacyPlayer in _remote_players.values():
		player.queue_free()
	_remote_players.clear()
	_roster_size = 0
	_local_slot_assigned = false
	if _local_player != null:
		_local_player.configure_solo_player()

func _on_peer_list_changed(peer_ids: Array[int]) -> void:
	if _local_player == null or not _local_player.is_network_session_active:
		return
	var new_peer_ids: Array[int] = []
	for peer_id: int in peer_ids:
		if peer_id != _local_player.network_peer_id and not _remote_players.has(peer_id):
			_spawn_remote_player(peer_id)
			new_peer_ids.append(peer_id)
	for peer_id: int in _remote_players.keys():
		if not peer_ids.has(peer_id):
			var player := _remote_players[peer_id] as PharmacyPlayer
			_remote_players.erase(peer_id)
			player.queue_free()
	var current_roster_size := peer_ids.size() + 1
	_apply_roster_slots(peer_ids, new_peer_ids)
	_roster_size = current_roster_size

func _spawn_remote_player(peer_id: int) -> void:
	if player_scene == null:
		return
	var player := player_scene.instantiate() as PharmacyPlayer
	if player == null:
		return
	player.locally_controlled = false
	player.name = "RemotePlayer_%d" % peer_id
	var peer_name := str(_network_session.peer_names.get(peer_id, "Jogador %d" % peer_id))
	player.configure_network_player(peer_id, false, peer_name)
	get_parent().add_child(player)
	var spawn := _get_spawn(1)
	if spawn != null:
		player.global_transform = spawn.global_transform
		player.set_remote_network_state(spawn.global_position, spawn.rotation.y, 0.0)
	_remote_players[peer_id] = player

func _apply_roster_slots(peer_ids: Array[int], new_peer_ids: Array[int]) -> void:
	var roster: Array[int] = peer_ids.duplicate()
	var local_id := _local_player.network_peer_id
	if local_id > 0 and not roster.has(local_id):
		roster.append(local_id)
	roster.sort()
	for index: int in range(roster.size()):
		var peer_id := roster[index]
		var spawn := _get_spawn(index)
		var color := PLAYER_COLORS[index % PLAYER_COLORS.size()]
		if peer_id == local_id:
			_local_player.set_network_color(color)
			if not _local_slot_assigned and not peer_ids.is_empty() and spawn != null:
				_local_player.global_transform = spawn.global_transform
				_local_player.set_safe_transform(spawn.global_transform)
				_local_slot_assigned = true
		elif _remote_players.has(peer_id):
			var player := _remote_players[peer_id] as PharmacyPlayer
			player.set_network_color(color)
			if peer_id in new_peer_ids and spawn != null:
				player.global_transform = spawn.global_transform
				player.set_remote_network_state(spawn.global_position, spawn.rotation.y, 0.0)

func _get_spawn(index: int) -> Node3D:
	match index:
		0: return host_spawn
		1: return client_spawn
		2: return client_spawn_2
		3: return client_spawn_3
	return client_spawn_3

func _on_peer_identity_changed(peer_id: int, persona_name: String) -> void:
	if _remote_players.has(peer_id):
		(_remote_players[peer_id] as PharmacyPlayer).set_network_display_name(persona_name)

func _on_player_state_received(peer_id: int, position: Vector3, yaw: float, head_pitch: float) -> void:
	if _local_player == null or peer_id == _local_player.network_peer_id:
		return
	if _remote_players.has(peer_id):
		(_remote_players[peer_id] as PharmacyPlayer).set_remote_network_state(position, yaw, head_pitch)
