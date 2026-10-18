extends RefCounted
## Shared warm timber / linen palette for story HUD and exploration journal.
const PAPER := Color("eee2ce")
const MUTED := Color("b9ad98")
const BRASS := Color("d5ac70")
const SAGE := Color("a7baa1")
const INK := Color(.105,.092,.077,.93)

static func panel(padding := 18.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = INK
	s.border_color = Color(.66,.53,.35,.42)
	s.set_border_width_all(1)
	s.border_width_top = 2
	s.set_corner_radius_all(5)
	s.set_content_margin_all(padding)
	s.shadow_color = Color(0,0,0,.20)
	s.shadow_size = 8
	return s

static func button(b: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var s := panel(10)
		s.shadow_size = 0
		s.bg_color = Color("493d2d") if state in ["hover","pressed"] else Color("302a22")
		if state == "focus":s.border_color = BRASS
		b.add_theme_stylebox_override(state,s)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_color_override("font_hover_color",Color("fff0d7"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func progress(current: int, total: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxi(1,total)
	bar.value = current
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color("40392e")
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",back)
	var fill := back.duplicate() as StyleBoxFlat
	fill.bg_color = SAGE if current >= total else BRASS
	bar.add_theme_stylebox_override("fill",fill)
	return bar
