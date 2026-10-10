extends Control
## Shop: category tabs, item cards with Buy/Owned/Equip/Equipped states,
## coin pill, and a confirmation dialog for expensive purchases.

const TABS: Array = [
	["all", "All"], ["bats", "Bats"], ["balls", "Balls"],
	["jerseys", "Jerseys"], ["shoes", "Shoes"], ["caps", "Caps"],
]

var _tab: String = "all"
var _coins_pill: PanelContainer
var _tab_btns: Array[Button] = []
var _list: VBoxContainer
var _confirm: ConfirmationDialog = null


func _ready() -> void:
	_tab = str(GameState.screen_params.get("category", "all"))
	if not _tab in ["all", "bats", "balls", "jerseys", "shoes", "caps"]:
		_tab = "all"
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Router.back()


func _build() -> void:
	add_child(GCLUI.paper_bg())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(head)
	var back := GCLUI.fx(ThemeHelpers.make_button("‹ Back", 56.0))
	back.custom_minimum_size = Vector2(150, 56)
	back.pressed.connect(func() -> void: Router.back())
	head.add_child(back)
	var t := ThemeHelpers.title_label("🛒 Shop", 30, ThemeHelpers.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_coins_pill = GCLUI.make_pill("🪙 %d" % Economy.coins())
	head.add_child(_coins_pill)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(tabs)
	_tab_btns.clear()
	for tab in TABS:
		var b := GCLUI.fx(ThemeHelpers.make_toggle(str(tab[1]), str(tab[0]) == _tab))
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab.bind(str(tab[0])))
		_tab_btns.append(b)
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill_list()


func _on_tab(tab_id: String) -> void:
	_tab = tab_id
	for i in TABS.size():
		_tab_btns[i].button_pressed = str(TABS[i][0]) == _tab
	_fill_list()


func _fill_list() -> void:
	GCLUI.clear(_list)
	var owned: Array = SaveSystem.data.get("equipment_owned", [])
	var equipped: Dictionary = SaveSystem.data.get("equipped", {})
	var count := 0
	for item in GCLShop.items():
		if not (item is Dictionary):
			continue
		var cat: String = str(item.get("category", ""))
		if _tab != "all" and cat != _tab:
			continue
		_list.add_child(_item_card(item, owned, equipped))
		count += 1
	if count == 0:
		_list.add_child(ThemeHelpers.body_label("Nothing here yet.", 20, ThemeHelpers.MUTED))


func _item_card(item: Dictionary, owned: Array, equipped: Dictionary) -> PanelContainer:
	var panel := ThemeHelpers.make_panel(Vector2(0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)
	var icon := ThemeHelpers.title_label(str(item.get("icon", "🏏")), 40, ThemeHelpers.INK)
	# No wrapping: in the HBox an autowrap label collapses to ~1px and the
	# glyph paints over the neighbouring text.
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon.custom_minimum_size = Vector2(56, 0)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(ThemeHelpers.body_label(str(item.get("name", "?")), 22, ThemeHelpers.INK))
	info.add_child(ThemeHelpers.body_label(GCLUI.bonus_text(item.get("bonus", {})), 17, ThemeHelpers.MUTED))
	var desc := ThemeHelpers.body_label(str(item.get("description", "")), 16, ThemeHelpers.MUTED)
	info.add_child(desc)

	var iid: String = str(item.get("id", ""))
	var cat: String = str(item.get("category", ""))
	var is_equipped: bool = str(equipped.get(cat, "")) == iid
	var is_owned: bool = owned.has(iid)
	var price: int = int(item.get("price", 0))
	var b: Button
	if is_equipped:
		b = ThemeHelpers.make_button("Equipped ✓", 52.0)
		b.disabled = true
	elif is_owned:
		b = GCLUI.fx(ThemeHelpers.make_button("Equip", 52.0))
		b.pressed.connect(_on_equip.bind(iid))
	else:
		b = GCLUI.fx(ThemeHelpers.make_button("🪙 %d" % price, 52.0))
		b.disabled = Economy.coins() < price
		b.pressed.connect(_on_buy_pressed.bind(item))
	b.custom_minimum_size = Vector2(190, 52)
	row.add_child(b)
	return panel


func _on_equip(iid: String) -> void:
	Economy.equip(iid)
	SaveSystem.save_game()
	AudioMan.play("unlock")
	_fill_list()


func _on_buy_pressed(item: Dictionary) -> void:
	var price: int = int(item.get("price", 0))
	if price > 1000:
		if _confirm != null:
			_confirm.queue_free()
		_confirm = ConfirmationDialog.new()
		_confirm.dialog_text = "Buy %s for 🪙%d?" % [str(item.get("name", "?")), price]
		_confirm.ok_button_text = "Buy"
		_confirm.cancel_button_text = "Cancel"
		add_child(_confirm)
		_confirm.confirmed.connect(_do_buy.bind(str(item.get("id", ""))))
		_confirm.popup_centered()
	else:
		_do_buy(str(item.get("id", "")))


func _do_buy(iid: String) -> void:
	if Economy.purchase(iid):
		AudioMan.play("coin")
		SaveSystem.save_game()
		GCLUI.set_pill_text(_coins_pill, "🪙 %d" % Economy.coins())
		_fill_list()
	else:
		AudioMan.play("loss")
		GCLUI.set_pill_text(_coins_pill, "🪙 %d — need more!" % Economy.coins())
