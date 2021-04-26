extends Label

var displayed_money = 0

func _process(delta):
	var root = get_node("../..")
	var money = root.money
	
	if displayed_money < money:
		displayed_money += (money - displayed_money) * 10.0 * delta
		displayed_money = min(displayed_money, money)
	if displayed_money > money:
		displayed_money += (money - displayed_money) * 10.0 * delta
		displayed_money = max(displayed_money, money)
	
	text = "$ " + str(round(displayed_money))
