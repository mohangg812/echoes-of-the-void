class_name LocalSave
extends RefCounted


static func read_json(path: String, size_limit: int = 1048576) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > size_limit:
		return null
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		return null
	return parser.data


static func replace_json(path: String, data: Dictionary) -> Error:
	var temporary: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data))
	f.flush()
	var write_error: Error = f.get_error()
	f.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, path)
