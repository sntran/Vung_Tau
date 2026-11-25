extends SceneTree
## Plan 0031, D5: makes a pack of Godot (PCKPacker) with resources of the
## project, for the web build: for an imported resource, its .import file and
## each file that the import made (its "dest_files"), as an export has them.
## Run after an import of the project:
##   godot --headless --path . -s tools/web/make_pack.gd -- OUT.pck res://PATH ...


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("make_pack.gd: OUT.pck and at least one res:// path")
		quit(1)
		return
	var packer := PCKPacker.new()
	if packer.pck_start(args[0]) != OK:
		push_error("make_pack.gd: cannot write %s" % args[0])
		quit(1)
		return
	var count := 0
	for res_path in args.slice(1):
		for file in files_of(res_path):
			if packer.add_file(file, ProjectSettings.globalize_path(file)) != OK:
				push_error("make_pack.gd: cannot add %s" % file)
				quit(1)
				return
			count += 1
	packer.flush()
	print("make_pack.gd: %d files in %s" % [count, args[0]])
	quit(0)


## The files of a resource in a pack: an imported resource has its .import
## file and the files of the import; another file is itself.
static func files_of(res_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var import_path := res_path + ".import"
	if not FileAccess.file_exists(import_path):
		out.append(res_path)
		return out
	out.append(import_path)
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return out
	for file: String in config.get_value("deps", "dest_files", []):
		if FileAccess.file_exists(file):
			out.append(file)
	return out
