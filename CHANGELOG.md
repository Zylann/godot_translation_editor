Changelog
============

This is a high-level changelog for each released versions of the plugin.
For a more detailed list of past and incoming changes, see the commit history.


0.3 - Switch to Godot 3.1
---------------------------

- Minimal supported version of Godot is now 3.1
- Added support for string prefix
- Added support for JSON and C# files (preferably useful with string prefix)
- Added options in ProjectSettings (category `TranslationEditor`)
- Limited prints to warnings and errors, the rest uses Godot's verbose option
- Typed GDScript is now used in the plugin's codebase
- Fixed `tr()` calls within an str() call not being detected
- Fixed calls to `TranslationServer.translate()` not being detected
- Fixed renaming a string key not marking files as changed
- Fixed window titles not being detected
- Fixed previous extraction results not being cleared when opening the dialog again
- Fixed "clear search" button not updating search results and remaining shown


0.2
---

- Added string extractor
- Implemented search
- Implemented string removal
- Fix .po files not being saved with config headers


0.1
----

- Released plugin on the asset lib
