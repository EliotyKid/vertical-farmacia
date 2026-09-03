extends Node

signal world_state_changed(summary: String)

const WORLD_ITEM_SCENE := preload("res://items/world_item.tscn")
const DELIVERY_BOX_SCENE := preload("res://items/delivery_box.tscn")
const MODE_WORLD := 0
const MODE_CARRIED := 1
const MODE_STORED := 2

var _session: Node
var _next_item_id: int = 1
var _items: Dictionary = {}
var _item_modes: Dictionary = {}
var _item_holders: Dictionary = {}
var _item_shelves: Dictionary = {}
var _item_slots: Dictionary = {}
var _sync_accumulator: float = 0.0

func _ready() -> void:
	_session = get_node_or_null("/root/NetworkSession")
	if _session == null:
		return
	_session.session_started.connect(_on_session_started)
	_session.session_ended.connect(_on_session_ended)
	_session.peer_list_changed.connect(_on_peer_list_changed)
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	if not is_network_active():
		return
	if is_host():
		_register_untracked_host_items()
		_sync_accumulator += delta
		if _sync_accumulator >= 0.05:
			_sync_accumulator = 0.0
			_broadcast_world_transforms()
	_update_carried_transforms()

func is_network_active() -> bool:
	return _session != null and _session._steam_peer != null

func is_host() -> bool:
	return is_network_active() and bool(_session.is_session_host)

func get_debug_summary() -> String:
	if not is_network_active():
		return "mundo solo"
	var carried := 0
	var stored := 0
	for item_id: int in _item_modes:
		match int(_item_modes[item_id]):
			MODE_CARRIED:
				carried += 1
			MODE_STORED:
				stored += 1
	return "itens %d • carregados %d • guardados %d" % [_items.size(), carried, stored]

func get_carried_item(peer_id: int) -> WorldItem:
	return _items.get(_get_carried_item_id(peer_id)) as WorldItem

func get_item_by_id(item_id: int) -> WorldItem:
	return _items.get(item_id) as WorldItem

func authority_store_carried(peer_id: int, target_transform: Transform3D) -> WorldItem:
	if not is_host():
		return null
	var item := get_carried_item(peer_id)
	if item == null:
		return null
	_set_authoritative_state(item.network_item_id, MODE_STORED, 0, &"", -1, target_transform)
	return item

func authority_pick_up_item(peer_id: int, item_id: int) -> bool:
	if not is_host():
		return false
	_authority_pick_up(peer_id, item_id)
	return _get_carried_item_id(peer_id) == item_id

func authority_consume_carried(peer_id: int) -> ItemData:
	if not is_host():
		return null
	var item := get_carried_item(peer_id)
	if item == null:
		return null
	var data := item.item_data
	_clear_item_from_players(item)
	item.queue_free()
	return data

func authority_remove_item(item: WorldItem) -> bool:
	if not is_host() or item == null or item.network_item_id <= 0:
		return false
	_clear_item_from_shelves(item)
	_clear_item_from_players(item)
	item.queue_free()
	return true

func prepare_host_shutdown() -> void:
	if not is_host():
		return
	var local_peer_id := multiplayer.get_unique_id()
	var holders: Array[int] = []
	for item_id: int in _item_holders:
		var holder := int(_item_holders[item_id])
		if holder > 0 and holder != local_peer_id and not holders.has(holder):
			holders.append(holder)
	for holder: int in holders:
		_authority_release_disconnected_peer(holder)

func request_pick_up(item: WorldItem, player: PharmacyPlayer) -> bool:
	if not is_network_active() or item == null or player == null:
		return false
	var item_id := item.network_item_id
	if item_id <= 0:
		return false
	if is_host():
		_authority_pick_up(multiplayer.get_unique_id(), item_id)
	else:
		_request_pick_up.rpc_id(1, item_id)
	return true

func request_drop(player: PharmacyPlayer) -> bool:
	if not is_network_active() or player == null:
		return false
	if is_host():
		_authority_drop(multiplayer.get_unique_id())
	else:
		_request_drop.rpc_id(1)
	return true

func request_shelf_interaction(player: PharmacyPlayer, shelf_id: StringName, slot_index: int) -> bool:
	if not is_network_active() or player == null:
		return false
	if is_host():
		_authority_shelf_interaction(multiplayer.get_unique_id(), shelf_id, slot_index)
	else:
		_request_shelf_interaction.rpc_id(1, shelf_id, slot_index)
	return true

func request_unpack(box: DeliveryBox, player: PharmacyPlayer) -> bool:
	if not is_network_active() or box == null or player == null:
		return false
	if is_host():
		_authority_unpack(multiplayer.get_unique_id(), box.network_item_id)
	else:
		_request_unpack.rpc_id(1, box.network_item_id)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_pick_up(item_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and _allow_request(sender, &"pickup", 75):
		_authority_pick_up(sender, item_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_drop() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and _allow_request(sender, &"drop", 100):
		_authority_drop(sender)

@rpc("any_peer", "call_remote", "reliable")
func _request_shelf_interaction(shelf_id: StringName, slot_index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and _allow_request(sender, &"shelf", 100):
		_authority_shelf_interaction(sender, shelf_id, slot_index)

@rpc("any_peer", "call_remote", "reliable")
func _request_unpack(item_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and _allow_request(sender, &"unpack", 150):
		_authority_unpack(sender, item_id)

func _allow_request(peer_id: int, channel: StringName, interval_ms: int) -> bool:
	return _session != null and _session.allow_authority_request(peer_id, channel, interval_ms)

func _authority_pick_up(peer_id: int, item_id: int) -> void:
	var item := _items.get(item_id) as WorldItem
	var player := _find_player(peer_id)
	if item == null or player == null or _get_carried_item_id(peer_id) != 0:
		return
	if int(_item_modes.get(item_id, MODE_WORLD)) == MODE_CARRIED:
		return
	if player.global_position.distance_to(item.global_position) > 3.5:
		return
	_clear_item_from_shelves(item)
	_set_authoritative_state(item_id, MODE_CARRIED, peer_id, &"", -1, item.global_transform)

func _authority_drop(peer_id: int) -> void:
	var item_id := _get_carried_item_id(peer_id)
	var item := _items.get(item_id) as WorldItem
	var player := _find_player(peer_id)
	if item == null or player == null:
		return
	var drop_transform := item.global_transform
	drop_transform.origin = player.get_hold_transform().origin
	_set_authoritative_state(item_id, MODE_WORLD, 0, &"", -1, drop_transform)

func _authority_shelf_interaction(peer_id: int, shelf_id: StringName, slot_index: int) -> void:
	var shelf := _find_shelf(shelf_id)
	var player := _find_player(peer_id)
	if shelf == null or player == null or slot_index < 0 or slot_index >= shelf.slots.size():
		return
	var slot := shelf.slots[slot_index] as ShelfSlot
	if player.global_position.distance_to(slot.item_marker.global_position) > 3.5:
		return
	var carried_id := _get_carried_item_id(peer_id)
	if carried_id != 0:
		var carried := _items.get(carried_id) as WorldItem
		if slot.stored_item != null or not shelf.accepts_item(carried):
			return
		_set_authoritative_state(carried_id, MODE_STORED, 0, shelf_id, slot_index, slot.item_marker.global_transform)
	elif slot.stored_item != null:
		_authority_pick_up(peer_id, slot.stored_item.network_item_id)

func _authority_unpack(peer_id: int, item_id: int) -> void:
	var box := _items.get(item_id) as DeliveryBox
	var player := _find_player(peer_id)
	if box == null or player == null or int(_item_modes.get(item_id, MODE_WORLD)) != MODE_WORLD:
		return
	if player.global_position.distance_to(box.global_position) > 3.5 or not box.has_been_carried():
		return
	box.authority_unpack()

func _set_authoritative_state(item_id: int, mode: int, holder: int, shelf_id: StringName, slot_index: int, item_transform: Transform3D) -> void:
	_apply_item_state(item_id, mode, holder, shelf_id, slot_index, item_transform)
	_apply_item_state.rpc(item_id, mode, holder, shelf_id, slot_index, item_transform)

@rpc("authority", "call_remote", "reliable")
func _apply_item_state(item_id: int, mode: int, holder: int, shelf_id: StringName, slot_index: int, item_transform: Transform3D) -> void:
	var item := _items.get(item_id) as WorldItem
	if item == null:
		return
	_clear_item_from_shelves(item)
	_clear_item_from_players(item)
	_item_modes[item_id] = mode
	_item_holders[item_id] = holder
	_item_shelves[item_id] = shelf_id
	_item_slots[item_id] = slot_index
	match mode:
		MODE_CARRIED:
			item.set_carried(true)
			var player := _find_player(holder)
			if player != null:
				player.apply_network_carried_item(item)
		MODE_STORED:
			item.global_transform = item_transform
			item.set_stored(true)
			var shelf := _find_shelf(shelf_id)
			if shelf != null and slot_index >= 0 and slot_index < shelf.slots.size():
				var slot := shelf.slots[slot_index] as ShelfSlot
				slot.stored_item = item
				item.global_transform = slot.item_marker.global_transform
				shelf.refresh_status()
		MODE_WORLD:
			item.global_transform = item_transform
			item.set_carried(false)
			if not is_host():
				item.freeze = true
			item.mark_current_transform_safe()
	world_state_changed.emit("Itens sincronizados: %d" % _items.size())

func _register_untracked_host_items() -> void:
	for node: Node in get_tree().get_nodes_in_group("network_world_item"):
		var item := node as WorldItem
		if item != null and item.network_item_id <= 0:
			_register_host_item(item)

func _register_host_item(item: WorldItem) -> void:
	item.network_item_id = _next_item_id
	_next_item_id += 1
	_items[item.network_item_id] = item
	_item_modes[item.network_item_id] = MODE_WORLD
	_item_holders[item.network_item_id] = 0
	_item_shelves[item.network_item_id] = &""
	_item_slots[item.network_item_id] = -1
	item.tree_exiting.connect(_on_host_item_exiting.bind(item.network_item_id), CONNECT_ONE_SHOT)
	_spawn_item.rpc(_serialize_item(item))

func _serialize_item(item: WorldItem) -> Dictionary:
	var data := {
		"id": item.network_item_id,
		"scene": "box" if item is DeliveryBox else "item",
		"item_path": item.item_data.resource_path if item.item_data != null else "",
		"transform": item.global_transform,
		"mode": int(_item_modes.get(item.network_item_id, MODE_WORLD)),
		"holder": int(_item_holders.get(item.network_item_id, 0)),
		"shelf": StringName(_item_shelves.get(item.network_item_id, &"")),
		"slot": int(_item_slots.get(item.network_item_id, -1)),
	}
	if item is DeliveryBox:
		var box := item as DeliveryBox
		data["content_path"] = box.content_data.resource_path if box.content_data != null else ""
		data["quantity"] = box.quantity
		data["carried_once"] = box.has_been_carried()
	return data

@rpc("authority", "call_remote", "reliable")
func _spawn_item(data: Dictionary) -> void:
	var item_id := int(data.get("id", 0))
	if item_id <= 0 or _items.has(item_id):
		return
	var item: WorldItem
	if str(data.get("scene", "item")) == "box":
		var box := DELIVERY_BOX_SCENE.instantiate() as DeliveryBox
		var content := load(str(data.get("content_path", ""))) as ItemData
		if content == null:
			return
		box.configure(content, int(data.get("quantity", 1)))
		box.set_has_been_carried(bool(data.get("carried_once", false)))
		item = box
	else:
		item = WORLD_ITEM_SCENE.instantiate() as WorldItem
		item.item_data = load(str(data.get("item_path", ""))) as ItemData
	if item == null or item.item_data == null:
		return
	item.network_item_id = item_id
	get_tree().current_scene.add_child(item)
	item.global_transform = data.get("transform", Transform3D.IDENTITY)
	_items[item_id] = item
	_item_modes[item_id] = int(data.get("mode", MODE_WORLD))
	_item_holders[item_id] = int(data.get("holder", 0))
	_item_shelves[item_id] = StringName(data.get("shelf", &""))
	_item_slots[item_id] = int(data.get("slot", -1))
	_apply_item_state(item_id, int(_item_modes[item_id]), int(_item_holders[item_id]), StringName(_item_shelves[item_id]), int(_item_slots[item_id]), item.global_transform)

func _send_snapshot(peer_id: int) -> void:
	var snapshot: Array[Dictionary] = []
	for item: WorldItem in _items.values():
		snapshot.append(_serialize_item(item))
	_receive_snapshot.rpc_id(peer_id, snapshot)

@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(snapshot: Array[Dictionary]) -> void:
	_clear_client_items()
	for data: Dictionary in snapshot:
		_spawn_item(data)

func _broadcast_world_transforms() -> void:
	for item_id: int in _items:
		if int(_item_modes.get(item_id, MODE_WORLD)) == MODE_WORLD:
			var item := _items[item_id] as WorldItem
			_sync_world_transform.rpc(item_id, item.global_transform)

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_world_transform(item_id: int, item_transform: Transform3D) -> void:
	var item := _items.get(item_id) as WorldItem
	if item != null and int(_item_modes.get(item_id, MODE_WORLD)) == MODE_WORLD:
		item.global_transform = item_transform

func _update_carried_transforms() -> void:
	for item_id: int in _items:
		if int(_item_modes.get(item_id, MODE_WORLD)) != MODE_CARRIED:
			continue
		var item := _items[item_id] as WorldItem
		var player := _find_player(int(_item_holders.get(item_id, 0)))
		if item != null and player != null:
			item.global_transform = player.get_hold_transform()

func _on_session_started(_local_peer_id: int, host: bool) -> void:
	_next_item_id = 1
	_items.clear()
	_item_modes.clear()
	_item_holders.clear()
	_item_shelves.clear()
	_item_slots.clear()
	if host:
		_register_untracked_host_items()
	else:
		_clear_client_items()

func _on_session_ended() -> void:
	_items.clear()
	_item_modes.clear()
	_item_holders.clear()
	_item_shelves.clear()
	_item_slots.clear()

func _on_peer_list_changed(peer_ids: Array[int]) -> void:
	if not is_host():
		return
	var valid_peers: Array[int] = peer_ids.duplicate()
	var local_peer_id := multiplayer.get_unique_id()
	if not valid_peers.has(local_peer_id):
		valid_peers.append(local_peer_id)
	var disconnected_holders: Array[int] = []
	for item_id: int in _item_holders:
		var holder := int(_item_holders[item_id])
		if holder > 0 and not valid_peers.has(holder) and not disconnected_holders.has(holder):
			disconnected_holders.append(holder)
	for holder: int in disconnected_holders:
		_authority_release_disconnected_peer(holder)
	for peer_id: int in peer_ids:
		_send_snapshot(peer_id)

func _authority_release_disconnected_peer(peer_id: int) -> void:
	var item_id := _get_carried_item_id(peer_id)
	var item := _items.get(item_id) as WorldItem
	if item == null:
		return
	var drop_transform := item.global_transform
	var player := _find_player(peer_id)
	if player != null:
		drop_transform.origin = player.get_hold_transform().origin
	_set_authoritative_state(item_id, MODE_WORLD, 0, &"", -1, drop_transform)

func _on_node_added(node: Node) -> void:
	if not is_network_active() or not node is WorldItem:
		return
	var item := node as WorldItem
	if is_host():
		call_deferred("_register_untracked_host_items")
	elif item.network_item_id <= 0:
		item.call_deferred("queue_free")

func _on_host_item_exiting(item_id: int) -> void:
	_items.erase(item_id)
	_item_modes.erase(item_id)
	_item_holders.erase(item_id)
	_item_shelves.erase(item_id)
	_item_slots.erase(item_id)
	if is_host():
		_despawn_item.rpc(item_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_item(item_id: int) -> void:
	var item := _items.get(item_id) as WorldItem
	_items.erase(item_id)
	_item_modes.erase(item_id)
	_item_holders.erase(item_id)
	_item_shelves.erase(item_id)
	_item_slots.erase(item_id)
	if item != null:
		_clear_item_from_players(item)
		_clear_item_from_shelves(item)
		item.queue_free()

func _clear_client_items() -> void:
	for node: Node in get_tree().get_nodes_in_group("network_world_item"):
		if node is WorldItem:
			node.queue_free()
	_items.clear()
	_item_modes.clear()
	_item_holders.clear()
	_item_shelves.clear()
	_item_slots.clear()

func _get_carried_item_id(peer_id: int) -> int:
	for item_id: int in _item_holders:
		if int(_item_holders[item_id]) == peer_id and int(_item_modes.get(item_id, MODE_WORLD)) == MODE_CARRIED:
			return item_id
	return 0

func _find_player(peer_id: int) -> PharmacyPlayer:
	for node: Node in get_tree().get_nodes_in_group("network_player"):
		var player := node as PharmacyPlayer
		if player != null and player.network_peer_id == peer_id:
			return player
	return null

func _find_shelf(shelf_id: StringName) -> PharmacyShelf:
	for node: Node in get_tree().get_nodes_in_group("network_shelf"):
		var shelf := node as PharmacyShelf
		if shelf != null and shelf.network_shelf_id == shelf_id:
			return shelf
	return null

func _clear_item_from_players(item: WorldItem) -> void:
	for node: Node in get_tree().get_nodes_in_group("network_player"):
		var player := node as PharmacyPlayer
		if player != null:
			player.clear_network_carried_item(item)

func _clear_item_from_shelves(item: WorldItem) -> void:
	for node: Node in get_tree().get_nodes_in_group("network_shelf"):
		var shelf := node as PharmacyShelf
		if shelf == null:
			continue
		for slot: ShelfSlot in shelf.slots:
			if slot.stored_item == item:
				slot.stored_item = null
				shelf.refresh_status()
