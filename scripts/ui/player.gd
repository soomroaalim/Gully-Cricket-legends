extends Control
## Player profile (v1.2): shows one player — the user's own (default) or
## a teammate via GameState.screen_params["player_id"].
##
## Own profile: rename, kit colors, equipment shortcuts, effective stat
## bars, plus management buttons (Upgrade, Make Captain, Move Up/Down)
## relocated here from the team screen.
##
## Teammate profile: identity card (no rename/kit), raw stat bars
## (equipment is the user's only — never shown as the mate's),
## management buttons, and a "Compare with me" button opening a
## read-only side-by-side comparison overlay.
##
## Opening a profile never changes selection, captain, or lineup.

var _name_edit: LineEdit
var _overlay: Control = null
var _compare_mate_id: String = ""
var _compare_pick: OptionButton = null
var _compare_host: VBoxContainer = null


## Pure logic: side-by-side comparison rows. Missing keys are safe
## (leader "na", no crash). leader: "user" / "mate" / "tie" / "na".
static func compare_rows(user: Dictionary, mate: Dictionary) -> Array:
	var rows: Array = []
	var defs: Array = [
		["overall", "Overall"], ["batting", "Batting"], ["bowling", "Bowling"],
		["fielding", "Fielding"], ["speed", "Speed"], ["stamina", "Stamina"],
		["level", "Level"],
	]
	for d in defs:
		var key: String = str(d[0])
		var row := {"key": key, "label": str(d[1]), "uval": 0, "mval": 0, "leader": "na"}
		if user.has(key) and mate.has(key):
			var u: int = int(user.get(key, 0))
			var m: int = int(mate.get(key, 0))
			row["uval"] = u
			row["mval"] = m
			if u > m:
				row["leader"] = "user"
			elif m > u:
				row["leader"] = "mate"
			else:
				row["leader"] = "tie"
		rows.append(row)
	return rows


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _overlay != null:
		_close_overlay()
		return
	Router.back()


func _viewed_player() -> Dictionary:
	var pid: String = str(GameState.screen_params.get("player_id", ""))
	if pid != "":
		for p in SaveSystem.data.get("team", []):
			if p is Dictionary and str(p.get("id", "")) == pid:
				return p
	return GCLUI.user_player()


func _refresh() -> void:
	_close_overlay()
	GCLUI.clear(self)
	_build()


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

	var p: Dictionary = _viewed_player()
	if p.is_empty():
		GCLUI.screen_head(root, "👤 Player", func() -> void: Router.back())
		root.add_child(ThemeHelpers.body_label("No player found — finish onboarding first.", 20, ThemeHelpers.RED))
		return
	var is_user: bool = bool(p.get("is_user", false))
	var title := "👤 My Player" if is_user else "👤 %s" % str(p.get("name", "?"))
	GCLUI.screen_head(root, title, func() -> void: Router.back())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_build_identity(body, p, is_user)
	_build_stats(body, p, is_user)
	if is_user:
		_build_equipment(body)
		_build_kit(body, p)
	_build_management(body, p, is_user)
	if not is_user:
		var cmp := GCLUI.fx(ThemeHelpers.make_button("⚖  Compare with me"))
		cmp.pressed.connect(_open_compare.bind(str(p.get("id", ""))))
		body.add_child(cmp)

	# Test/review hook: open the comparison straight away.
	if not is_user and bool(GameState.screen_params.get("show_compare", false)):
		_open_compare.call_deferred(str(p.get("id", "")))


# ------------------------------------------------------------- cards --
func _build_identity(body: VBoxContainer, p: Dictionary, is_user: bool) -> void:
	var card := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(top)
	var name: String = str(p.get("name", "?"))
	var jersey := Color(str(GCLUI.COSMETIC_COLORS[absi(int(p.get("jersey", 0))) % GCLUI.COSMETIC_COLORS.size()]))
	top.add_child(MenuArt.AvatarMedallion.new(name.left(1).to_upper(), jersey))
	var idcol := VBoxContainer.new()
	idcol.add_theme_constant_override("separation", 6)
	idcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(idcol)
	if is_user:
		var namerow := HBoxContainer.new()
		namerow.add_theme_constant_override("separation", 8)
		idcol.add_child(namerow)
		_name_edit = LineEdit.new()
		_name_edit.text = name
		_name_edit.max_length = 16
		_name_edit.custom_minimum_size = Vector2(0, 56)
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.add_theme_font_size_override("font_size", 24)
		namerow.add_child(_name_edit)
		var save_b := GCLUI.fx(ThemeHelpers.make_button("💾", 56.0))
		save_b.custom_minimum_size = Vector2(90, 56)
		save_b.pressed.connect(_on_save_name)
		namerow.add_child(save_b)
	else:
		var nm := ThemeHelpers.title_label(name, 28, ThemeHelpers.INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		idcol.add_child(nm)
	idcol.add_child(ThemeHelpers.body_label("Overall %d · Level %d" % [int(p.get("overall", 0)), int(p.get("level", 1))], 22, ThemeHelpers.INK))
	# XP bar.
	var lvl: int = int(p.get("level", 1))
	var need: int = GCLConfig.xp_for_level(lvl)
	idcol.add_child(ThemeHelpers.body_label("XP %d / %d" % [int(p.get("xp", 0)), need], 17, ThemeHelpers.MUTED))
	var xpbar := ProgressBar.new()
	xpbar.min_value = 0
	xpbar.max_value = maxi(need, 1)
	xpbar.value = int(p.get("xp", 0))
	xpbar.show_percentage = false
	xpbar.custom_minimum_size = Vector2(0, 16)
	var xbg := StyleBoxFlat.new()
	xbg.bg_color = Color(0, 0, 0, 0.18)
	xbg.set_corner_radius_all(8)
	var xfill := StyleBoxFlat.new()
	xfill.bg_color = ThemeHelpers.GOLD
	xfill.set_corner_radius_all(8)
	xpbar.add_theme_stylebox_override("background", xbg)
	xpbar.add_theme_stylebox_override("fill", xfill)
	idcol.add_child(xpbar)


func _build_stats(body: VBoxContainer, p: Dictionary, is_user: bool) -> void:
	var scard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(scard)
	var scol := ThemeHelpers.vbox(8)
	scol.alignment = BoxContainer.ALIGNMENT_BEGIN
	scard.add_child(scol)
	if is_user:
		scol.add_child(ThemeHelpers.title_label("📊 Stats (with gear)", 22, ThemeHelpers.RED))
		var eff: Dictionary = Economy.effective_stats(p)
		for key in GCLUI.STAT_KEYS:
			scol.add_child(GCLUI.make_stat_bar(str(GCLUI.STAT_LABELS[key]), int(eff.get(key, p.get(key, 50)))))
	else:
		# Raw stats: equipment belongs to the user only, so it is never
		# folded into a teammate's numbers.
		scol.add_child(ThemeHelpers.title_label("📊 Stats", 22, ThemeHelpers.RED))
		for key in GCLUI.STAT_KEYS:
			scol.add_child(GCLUI.make_stat_bar(str(GCLUI.STAT_LABELS[key]), int(p.get(key, 50))))


func _build_equipment(body: VBoxContainer) -> void:
	var ecard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(ecard)
	var ecol := ThemeHelpers.vbox(8)
	ecol.alignment = BoxContainer.ALIGNMENT_BEGIN
	ecard.add_child(ecol)
	ecol.add_child(ThemeHelpers.title_label("🧤 Equipment", 22, ThemeHelpers.RED))
	var equipped: Dictionary = SaveSystem.data.get("equipped", {})
	for slot in GCLUI.SLOT_CATEGORIES:
		var cat: String = str(slot[1])
		var eid: String = str(equipped.get(cat, ""))
		var iname := "None"
		if eid != "":
			iname = str(GCLShop.by_id(eid).get("name", "Unknown"))
		var b := GCLUI.fx(ThemeHelpers.make_button("%s %s: %s  ›" % [str(slot[2]), str(slot[0]), iname], 52.0))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_open_shop_for.bind(cat))
		ecol.add_child(b)


func _build_kit(body: VBoxContainer, p: Dictionary) -> void:
	var ccard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(ccard)
	var ccol := ThemeHelpers.vbox(8)
	ccol.alignment = BoxContainer.ALIGNMENT_BEGIN
	ccard.add_child(ccol)
	ccol.add_child(ThemeHelpers.title_label("🎨 Kit Colors (free)", 22, ThemeHelpers.RED))
	for pair in [["Jersey", "jersey"], ["Cap", "cap"], ["Shoes", "shoes"], ["Bat skin", "bat_skin"]]:
		ccol.add_child(_swatch_row(str(pair[0]), str(pair[1]), p))


## Management actions relocated from the team screen.
func _build_management(body: VBoxContainer, p: Dictionary, is_user: bool) -> void:
	var pid: String = str(p.get("id", ""))
	var mcard := ThemeHelpers.make_panel(Vector2(0, 0))
	body.add_child(mcard)
	var mcol := ThemeHelpers.vbox(8)
	mcol.alignment = BoxContainer.ALIGNMENT_BEGIN
	mcard.add_child(mcol)
	mcol.add_child(ThemeHelpers.title_label("⚙ Manage", 22, ThemeHelpers.RED))
	var cost: int = Economy.upgrade_cost(p)
	var up := GCLUI.fx(ThemeHelpers.make_button("⬆  Upgrade  (🪙%d)" % cost))
	up.pressed.connect(_on_upgrade.bind(pid))
	mcol.add_child(up)
	var row := ThemeHelpers.hbox(10)
	mcol.add_child(row)
	var cap_b := GCLUI.fx(ThemeHelpers.make_button("⭐  Make Captain"))
	cap_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_b.pressed.connect(_on_make_captain.bind(pid))
	row.add_child(cap_b)
	var up_b := GCLUI.fx(ThemeHelpers.make_button("▲  Up"))
	up_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_b.pressed.connect(_on_move.bind(pid, -1))
	row.add_child(up_b)
	var dn_b := GCLUI.fx(ThemeHelpers.make_button("▼  Down"))
	dn_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dn_b.pressed.connect(_on_move.bind(pid, 1))
	row.add_child(dn_b)
	if not is_user:
		mcol.add_child(ThemeHelpers.body_label(
			"Kit colors and equipment are yours only — they stay on your profile.", 16, ThemeHelpers.MUTED))


# --------------------------------------------------------- comparison -
func _open_compare(mate_id: String) -> void:
	_close_overlay()
	_compare_mate_id = mate_id
	var panel := ThemeHelpers.make_panel(Vector2(640, 0))
	var col := ThemeHelpers.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("⚖ Player Comparison", 26, ThemeHelpers.RED))

	var user: Dictionary = GCLUI.user_player()
	var mates: Array = []
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary and not bool(p.get("is_user", false)):
			mates.append(p)
	if mates.is_empty():
		col.add_child(ThemeHelpers.body_label("Recruit teammates to compare.", 20, ThemeHelpers.MUTED))
	else:
		var pick := OptionButton.new()
		pick.custom_minimum_size = Vector2(0, 56)
		for m in mates:
			pick.add_item(str(m.get("name", "?")))
			pick.set_item_metadata(pick.item_count - 1, str(m.get("id", "")))
		var sel := 0
		for i in mates.size():
			if str(mates[i].get("id", "")) == mate_id:
				sel = i
		pick.selected = sel
		pick.item_selected.connect(_on_compare_pick)
		col.add_child(pick)
		_compare_pick = pick
		var rows_host := VBoxContainer.new()
		rows_host.add_theme_constant_override("separation", 6)
		col.add_child(rows_host)
		_compare_host = rows_host
		_fill_compare_rows(rows_host, user, mates[sel])

	var close := GCLUI.fx(ThemeHelpers.make_button("✖  Close"))
	close.pressed.connect(_close_overlay)
	col.add_child(close)
	_overlay = GCLUI.make_overlay(panel)
	add_child(_overlay)


func _on_compare_pick(idx: int) -> void:
	if _compare_pick == null or _compare_host == null:
		return
	var mate_id: String = str(_compare_pick.get_item_metadata(idx))
	var mate: Dictionary = {}
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary and str(p.get("id", "")) == mate_id:
			mate = p
			break
	if mate.is_empty():
		return
	_compare_mate_id = mate_id
	_fill_compare_rows(_compare_host, GCLUI.user_player(), mate)


func _compare_dicts(user: Dictionary, mate: Dictionary) -> Array:
	# User: effective stats (their gear counts). Mate: raw stats.
	var eff: Dictionary = Economy.effective_stats(user)
	var u := {
		"overall": int(user.get("overall", 0)), "level": int(user.get("level", 1)),
		"batting": int(eff.get("batting", 0)), "bowling": int(eff.get("bowling", 0)),
		"fielding": int(eff.get("fielding", 0)),
		"speed": int(user.get("speed", 0)), "stamina": int(user.get("stamina", 0)),
	}
	var m := {
		"overall": int(mate.get("overall", 0)), "level": int(mate.get("level", 1)),
		"batting": int(mate.get("batting", 0)), "bowling": int(mate.get("bowling", 0)),
		"fielding": int(mate.get("fielding", 0)),
		"speed": int(mate.get("speed", 0)), "stamina": int(mate.get("stamina", 0)),
	}
	return [u, m]


## v2.0: text rows for data that has no bar (recent form, selection status).
## Missing data shows "—", never a fabricated value.
func _compare_text_row(label_text: String, u_text: String, m_text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lab := ThemeHelpers.body_label(label_text, 18, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(96, 0)
	h.add_child(lab)
	for t in [u_text, m_text]:
		var cell := ThemeHelpers.body_label(t, 18, ThemeHelpers.INK)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(cell)
	return h


## v2.0: answers "why was he picked ahead of me / what do I improve?"
## from ACTUAL selection factors and real attributes. Read-only.
func _selection_insight(host: VBoxContainer, user: Dictionary, mate: Dictionary) -> void:
	var Selection := load("res://scripts/career/selection.gd")
	var factors: Dictionary = Career.selection_factors()
	var urole: String = str(user.get("role", ""))
	var mrole: String = str(mate.get("role", ""))
	var lines: Array[String] = []
	# Head-to-head on the stats that matter for each role.
	var prim: String = {"Batter": "batting", "Bowler": "bowling",
		"Wicketkeeper": "fielding", "AllRounder": "batting"}.get(urole, "batting")
	var uv: int = int(user.get(prim, 0))
	var mv: int = int(mate.get(prim, 0))
	var mname: String = str(mate.get("name", "teammate"))
	if urole == mrole:
		if mv > uv:
			lines.append("%s's %s (%d) tops yours (%d) — that is the gap for a %s slot." % [mname, prim, mv, uv, urole])
		elif uv > mv:
			lines.append("Your %s (%d) beats %s's (%d) — you have the edge for a %s slot." % [prim, uv, mname, mv, urole])
		else:
			lines.append("You match %s on %s (%d) — form will decide between you." % [mname, prim, uv])
	else:
		lines.append("%s is a %s and you are a %s — you rarely compete for the same XI slot." % [mname, mrole, urole])
	# What to improve: the weakest real selection factor.
	var form: float = float(factors.get("form", 0.5))
	var ability: float = float(factors.get("ability", 0.5))
	var role_fit: float = float(factors.get("role_fit", 0.5))
	var weakest: String = "form"
	var wv: float = form
	if ability < wv:
		weakest = "ability"
		wv = ability
	if role_fit < wv:
		weakest = "role"
	match weakest:
		"form":
			lines.append("To raise your %d%% selection chance: perform in reserve matches — recent form matters most." % int(round(Career.selection_chance() * 100.0)))
		"ability":
			lines.append("To raise your %d%% selection chance: upgrade your player — overall ability is holding you back." % int(round(Career.selection_chance() * 100.0)))
		_:
			lines.append("Your %d%% chance is limited by team needs — the XI is stocked in your role. Keep performing; openings come up." % int(round(Career.selection_chance() * 100.0)))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeHelpers.card_style())
	host.add_child(panel)
	var col := ThemeHelpers.vbox(6)
	panel.add_child(col)
	col.add_child(ThemeHelpers.title_label("Selection insight", 20, ThemeHelpers.RED))
	for ln in lines:
		var l := ThemeHelpers.body_label(ln, 16, ThemeHelpers.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)


func _fill_compare_rows(host: VBoxContainer, user: Dictionary, mate: Dictionary) -> void:
	GCLUI.clear(host)
	# Header row: labels for the two columns.
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	host.add_child(hrow)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(96, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(pad)
	var uh := ThemeHelpers.body_label("You", 18, ThemeHelpers.MUTED)
	uh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hrow.add_child(uh)
	var mh := ThemeHelpers.body_label(str(mate.get("name", "?")), 18, ThemeHelpers.MUTED)
	mh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hrow.add_child(mh)

	var dicts: Array = _compare_dicts(user, mate)
	for row in compare_rows(dicts[0], dicts[1]):
		host.add_child(_compare_row(row))
	# v2.0: recent form + selection status rows (real data; "—" when absent).
	var Selection := load("res://scripts/career/selection.gd")
	var uform_hist: Array = Career.sel().get("form", [])
	var uform_txt: String = "—"
	if not uform_hist.is_empty():
		uform_txt = "%d%%" % int(round(Selection.recent_form(uform_hist) * 100.0))
	host.add_child(_compare_text_row("Form", uform_txt, "—"))
	var mate_status: String = "Main XI" if SaveSystem.data.get("lineup", []).has(str(mate.get("id", ""))) else "Reserve"
	host.add_child(_compare_text_row("Status",
		Selection.status_label(Career.selection_status()), mate_status))
	_selection_insight(host, user, mate)


## One comparison row: label, user value+bar, mate value+bar.
## The leader is marked with "▲" and a bold value label (never color alone);
## ties show "=".
func _compare_row(row: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lab := ThemeHelpers.body_label(str(row.get("label", "")), 18, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(96, 0)
	h.add_child(lab)
	var leader: String = str(row.get("leader", "na"))
	h.add_child(_compare_cell(int(row.get("uval", 0)), leader == "user", leader == "tie"))
	h.add_child(_compare_cell(int(row.get("mval", 0)), leader == "mate", leader == "tie"))
	return h


func _compare_cell(value: int, is_leader: bool, is_tie: bool) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mark := ""
	if is_leader:
		mark = "▲ "
	elif is_tie:
		mark = "= "
	var lab := ThemeHelpers.body_label("%s%d" % [mark, value], 20, ThemeHelpers.INK)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_leader:
		_bold(lab)
	cell.add_child(lab)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 99
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.18)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeHelpers.GREEN if value >= 60 else (ThemeHelpers.GOLD if value >= 40 else ThemeHelpers.RED)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	cell.add_child(bar)
	return cell


## Genuine bold (FontVariation embolden) — the leader is never marked
## by color alone.
func _bold(lab: Label) -> void:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.8
	lab.add_theme_font_override("font", fv)


# ------------------------------------------------------------- actions -
func _on_save_name() -> void:
	var p: Dictionary = GCLUI.user_player()
	if p.is_empty():
		return
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Haroon"
		_name_edit.text = n
	p["name"] = n
	SaveSystem.data["player_name"] = n
	SaveSystem.save_game()
	AudioMan.play("coin")


func _player_by_id(pid: String) -> Dictionary:
	for p in SaveSystem.data.get("team", []):
		if p is Dictionary and str(p.get("id", "")) == pid:
			return p
	return {}


func _on_upgrade(pid: String) -> void:
	var p: Dictionary = _player_by_id(pid)
	if p.is_empty():
		return
	if Economy.upgrade_player(pid):
		AudioMan.play("coin")
		SaveSystem.save_game()
		_refresh()
	else:
		AudioMan.play("loss")


func _on_make_captain(pid: String) -> void:
	SaveSystem.data["captain_id"] = pid
	SaveSystem.save_game()
	AudioMan.play("unlock")
	_refresh()


func _on_move(pid: String, dir: int) -> void:
	var lineup: Array = SaveSystem.data.get("lineup", [])
	var i: int = lineup.find(pid)
	var j: int = i + dir
	if i < 0 or j < 0 or j >= lineup.size():
		return
	var tmp: Variant = lineup[i]
	lineup[i] = lineup[j]
	lineup[j] = tmp
	SaveSystem.data["lineup"] = lineup
	SaveSystem.save_game()
	_refresh()


func _open_shop_for(category: String) -> void:
	Router.show("shop", {"category": category})


func _swatch_row(label_text: String, key: String, p: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var lab := ThemeHelpers.body_label(label_text, 19, ThemeHelpers.MUTED)
	lab.custom_minimum_size = Vector2(110, 0)
	row.add_child(lab)
	var cur: int = int(p.get(key, 0))
	for i in GCLUI.COSMETIC_COLORS.size():
		var b := GCLUI.fx(Button.new())
		b.custom_minimum_size = Vector2(56, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = label_text
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(str(GCLUI.COSMETIC_COLORS[i]))
		sb.set_corner_radius_all(12)
		if i == cur:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(4)
		else:
			sb.border_color = Color(0, 0, 0, 0.25)
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_on_swatch.bind(key, i))
		row.add_child(b)
	return row


func _on_swatch(key: String, idx: int) -> void:
	var p: Dictionary = GCLUI.user_player()
	if p.is_empty():
		return
	p[key] = idx
	SaveSystem.save_game()
	_refresh()


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
