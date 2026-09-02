class_name Wallet
extends Node

signal money_changed(new_amount: int, difference: int)

@export_range(0, 100000, 1) var starting_money: int = 150

var money: int


func _ready() -> void:
	money = starting_money
	money_changed.emit(money, 0)


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


func try_spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money, -amount)
	return true


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money, amount)


func remove_money(amount: int) -> int:
	if amount <= 0 or money <= 0:
		return 0
	var removed := mini(amount, money)
	money -= removed
	money_changed.emit(money, -removed)
	return removed


func set_money(amount: int) -> void:
	var previous := money
	money = maxi(amount, 0)
	money_changed.emit(money, money - previous)
