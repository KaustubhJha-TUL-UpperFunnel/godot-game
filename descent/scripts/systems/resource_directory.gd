class_name ResourceDirectory
extends RefCounted

## Loads every .tres in a folder.
##
## The catalogs use this instead of hand-listing resources in the scene, so
## dropping a new upgrade or difficulty file into descent/data/ is enough to
## register it.


## Exported builds rename resources to `<file>.remap`, so the suffix is
## stripped before loading; the original path is what the loader expects.
static func load_all(directory: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	for entry in DirAccess.get_files_at(directory):
		var file_name := entry.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(directory.path_join(file_name))
		if resource != null:
			loaded.append(resource)

	if loaded.is_empty():
		push_warning("DESCENT: no resources found in %s" % directory)
	return loaded
