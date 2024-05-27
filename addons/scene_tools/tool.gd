extends RefCounted

const SceneTools := preload("res://addons/scene_tools/plugin.gd")
const Utils := preload("res://addons/scene_tools/utils.gd")

var plugin: SceneTools

func _init(_plugin: SceneTools = null) -> void:
    plugin = _plugin

func enter() -> void: pass
func exit() -> void: pass

func edit(_object: Object) -> void: pass
func forward_3d_gui_input(_viewport_camera: Camera3D, _event: InputEvent) -> int: return EditorPlugin.AFTER_GUI_INPUT_PASS
func handles(_object: Object) -> bool: return false

func load_state(_configuration: ConfigFile) -> void: pass
func save_state(_configuration: ConfigFile) -> void: pass

func _on_scene_changed(_scene_root: Node) -> void: pass
func _on_scene_closed(_path: String) -> void: pass

func _on_plugin_enabled(_enabled: bool) -> void: pass
