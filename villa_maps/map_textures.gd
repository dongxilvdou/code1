extends RefCounted
## Imports are local caches, not repository assets. A newly pulled PNG may not
## have a .ctex yet when the game is launched directly instead of in the editor.
static func load_texture(path: String, source_only: bool = false) -> Texture2D:
	var imported := ResourceLoader.exists(path) and not source_only
	var config := ConfigFile.new()
	if imported and config.load(path+".import")==OK:
		var cached_path: String = config.get_value("remap","path","")
		if not cached_path.is_empty() and not FileAccess.file_exists(cached_path):
			imported = false
	if imported:
		var texture := ResourceLoader.load(path) as Texture2D
		if texture!=null:return texture
	# Raw files are available in a source checkout; exported builds use the
	# normal imported resource branch above, so no export preset change is needed.
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))==OK:
			return ImageTexture.create_from_image(image)
	push_error("VillaMap: cannot load map image "+path)
	return null
