# AC7 Ultrawide Fix

English | [中文](README_zh.md)

Expands the 3D field of view for *Ace Combat 7* at ultrawide resolutions and corrects the scaling and position of the HUD, subtitles, confirmation dialogs and loading screens. The fix applies automatically on launch.

Choose either **script install** (`Install.cmd`) or **manual install**; both place the same files into the game.

## What the fix covers

- **3D**: horizontal FOV expanded to the actual viewport.
- **HUD**: original shader kept, horizontal offset corrected.

3D and UI scale with the viewport and are not tied to a fixed resolution; the HUD uses the primary monitor's aspect ratio at launch.

## Requirements

| Dependency | Purpose |
| --- | --- |
| [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases) (x64) | Loads the two ASI plugins |
| [UE4SS](https://www.nexusmods.com/acecombat7skiesunknown/mods/2474) (with UEHelpers) | Loads the UI scripts |
| [VC++ 2015–2022 x64 runtime](https://aka.ms/vs/17/release/vc_redist.x64.exe) | Required by the ASI plugins |

Install and configure the dependencies yourself.

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

## Option 1: Script install

1. Install the dependencies above.
2. Extract this patch and run `Install.cmd`.
3. Launch the game from Steam.

The installer locates Steam libraries automatically. If none or several are found, specify the game folder:

```powershell
.\Install.cmd -GameDirectory 'D:\Games\ACE COMBAT 7'
```

The installer verifies the patch files, checks the UE4SS/UEHelpers paths, copies the ASI plugins and Lua scripts, merges the mod lists and backs up every file it modifies. Install records are kept in `backups/` and `.local-state/` inside the tool folder.

### Uninstall

Run `Uninstall.cmd` to restore the state from before that install; external dependencies are left in place:

```powershell
.\Uninstall.cmd -GameDirectory 'G:\Games\ACE COMBAT 7'
```

If patch files were modified after installation, the uninstaller lists the conflicts and stops.

## Option 2: Manual install

1. Install the dependencies above.
2. Back up any same-named files already present at the target locations, plus `ue4ss/Mods/mods.txt` and `ue4ss/Mods/mods.json`.
3. Copy the patch files:

| File in this package | Copy to |
| --- | --- |
| `payload/AC7SceneProjection.asi` | Game root |
| `payload/AC7HUDCenter.asi` | Game root |
| `mod/AC7UIAspect/` | `ue4ss/Mods/AC7UIAspect/` |

4. Add this line to `ue4ss/Mods/mods.txt`, keeping other entries:

```text
AC7UIAspect : 1
```

5. Add or update the entry in `ue4ss/Mods/mods.json`:

```json
[
  { "mod_name": "AC7UIAspect", "mod_enabled": true }
]
```

6. Launch the game from Steam.

### Manual uninstall

Delete the two ASI plugins and `ue4ss/Mods/AC7UIAspect/` you copied, then restore the backed-up files and both mod lists.

> `Uninstall.cmd` relies on the install records created by `Install.cmd`. For a manual install, uninstall manually from your own backups.

## Building from source

Requirements: Windows x64, Visual Studio 2022 (or Build Tools) with the "Desktop development with C++" workload and Windows SDK, CMake 3.20+.

Run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

The script configures an x64 project and builds in Release.

Output:

```text
payload/
  AC7SceneProjection.asi
  AC7HUDCenter.asi
```

Once built, install the patch as usual.
