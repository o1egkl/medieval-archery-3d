# Project Agent Rules

- **Auto-push updates to GitHub**: Whenever you make and verify code, asset, or configuration updates in this repository, automatically stage, commit, and push them to `origin main` (`https://github.com/o1egkl/medieval-archery-3d.git`) without asking for confirmation.
- **Keep CI compatibility**: GitHub Actions builds Android APKs, Web Demo, and Windows Standalone EXE using `barichello/godot-ci:4.3`; ensure GDScript and project settings remain compatible with Godot 4.3+.
- **Windows Launcher**: Keep `play_windows.bat` launching the non-console GUI Godot executable (`Godot*_win64.exe`, without `_console`) or `cmd /c` fallback so no command prompt window stays open after exiting the game.
