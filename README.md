# AC7 Ultrawide Fix

English | [中文](README_zh.md)

Expands the 3D field of view for *Ace Combat 7* at ultrawide resolutions and corrects the scaling and position of the HUD, subtitles, confirmation dialogs and loading screens. The fix applies automatically on launch.

Choose **scripted installation** or **manual installation**.

## How it works

- **3D view**: adjusts camera projection to the actual viewport aspect ratio, widening the horizontal field of view while preserving the vertical field of view so ultrawide screens show more of the scene on either side.
- **HUD**: adjusts horizontal sampling coordinates in the original HUD shaders to center the HUD while preserving the proportions of text and graphics.
- **UI layout**: scripts adjust the final canvases for subtitles, confirmation dialogs and loading screens when interfaces are created or switched, centering them in a 16:9 area.

All fixes apply at runtime without modifying the game executable or assets. The 3D and UI adjustments use the viewport dimensions and are not tied to a fixed resolution; the HUD uses the primary monitor's aspect ratio at launch.

## Installation

### Prerequisites

| Dependency | Purpose |
| --- | --- |
| [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases) (x64) | Loads the two ASI plugins |
| [UE4SS](https://www.nexusmods.com/acecombat7skiesunknown/mods/2474) (with UEHelpers) | Loads the UI scripts |

Install and configure these dependencies separately.

The game root folder, i.e. the folder containing `Ace7Game.exe`, should look like this:

```text
ACE COMBAT 7/
  Ace7Game.exe
  dinput8.dll            ASI Loader
  dwmapi.dll             UE4SS loader
  ue4ss/
    UE4SS.dll
    UE4SS-settings.ini
    Mods/shared/UEHelpers/UEHelpers.lua
```

### Scripted installation

1. Install the prerequisites.
2. Run `Install.cmd`.

The installer automatically locates the game folder, checks the UE4SS/UEHelpers paths, copies the ASI plugins and Lua scripts, and merges the mod lists.

If it cannot find the game, specify the folder manually:

```powershell
.\Install.cmd -GameDirectory 'D:\Games\ACE COMBAT 7'
```

### Scripted uninstallation

Run `Uninstall.cmd` to remove the files installed by this patch and its entries in the mod lists.

To specify the folder:

```powershell
.\Uninstall.cmd -GameDirectory 'G:\Games\ACE COMBAT 7'
```

### Manual installation

1. Install the prerequisites.
2. Copy the mod files:

| File in this package | Copy to |
| --- | --- |
| `payload/AC7SceneProjection.asi` | Game root |
| `payload/AC7HUDCenter.asi` | Game root |
| `mod/AC7UIAspect/` | `ue4ss/Mods/AC7UIAspect/` |

3. Add this to `ue4ss/Mods/mods.txt`:

```text
AC7UIAspect : 1
```

4. Add this to `ue4ss/Mods/mods.json`:

```json
[
  { "mod_name": "AC7UIAspect", "mod_enabled": true }
]
```

### Manual uninstallation

Close the game and delete these files and folders:

- `AC7SceneProjection.asi`
- `AC7HUDCenter.asi`
- `AC7SceneProjection.log`, `AC7HUDCenter.log` (if present)
- `ue4ss/Mods/AC7UIAspect/`

Then remove the `AC7UIAspect` entries from `ue4ss/Mods/mods.txt` and `ue4ss/Mods/mods.json`.

Prerequisites do not need to be removed if other mods still use them.

## Building from source

Requirements: Visual Studio 2022 x64 MSVC, Windows SDK and CMake.

Run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

Output:

```text
payload/
  AC7SceneProjection.asi
  AC7HUDCenter.asi
```

Once built, install the patch as usual.

## License

This project is released under [GPL-3.0](LICENSE). Bundled third-party components retain their respective licenses.
