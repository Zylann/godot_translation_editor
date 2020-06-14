Translation editor for Godot Engine
=====================================

This is an editor plugin to edit translation files from inside Godot Engine. It supports .csv and .po files, although gettext support is limited to what Godot can handle. It can also be used as a standalone editor if `translation_editor.tscn` is run or exported as main scene.

It can extract strings from your project automatically and adds them to a list for you to translate. There is no particular convention to use.
The tool supports the following file types:
- `*.gd`: detects strings used with `tr()` and  `TranslationServer.translate()`.
- `*.tscn`: detects string properties known to be translatable

C# and binary files are not supported yet, but may be added in the future.
Some projects use a prefix convention to use strings in places harder to auto-detect, so supporting them may also be implemented.

![screenshot2](https://user-images.githubusercontent.com/1311555/48521813-14559600-e86e-11e8-8cf8-95580f97baf0.png)

How to install
-----------------

This is a regular editor plugin. Copy the contents of addons/zylann.translation_editor into the same folder in your project, and activate it in your project settings.


