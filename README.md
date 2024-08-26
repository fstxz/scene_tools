# Scene Tools
Scene Tools is an editor plugin for Godot 4.3+ to help you with editing your 3D levels and quick prototyping. It currently only supports asset placement.

The plugin supports any PackedScene files (.tscn, .gltf, .blend, etc).

![](screenshot_1.png)

## Currently implemented features
* Asset placement
  * Snapping support
  * Align to surface
  * Multiple assets selection (by holding Ctrl or Shift). When placing, random asset will be picked from the selection
  * Scale, rotation randomization
  * Area fill

## Installation
The plugin is available in the [Asset Library](https://godotengine.org/asset-library/asset/2846).

Follow [Godot documentation](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html) on how to install and enable plugins.

## How to use

> [!NOTE]
> These instructions are for v0.9.0. If you downloaded v0.8.x, read the instructions on the asset library page.

1. Select your asset in the filesystem dock.
2. Select any node in the scene tree. Objects will be spawned as children of this node.
3. Click "Scene Tools" button at the top (below 2D, 3D, etc) to open side panel. Plugin will be active only when the panel is visible.

You should now be able to place the asset.

## License
This plugin is licensed under the [MIT License](https://github.com/fstxz/scene_tools/blob/master/LICENSE.txt).
