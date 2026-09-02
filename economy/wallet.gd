class_name Wallet
extends Node

signal money_changed(new_amount: int, difference: int)

@export_range(0, 100000, 1) var starting_money: int = 40

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
