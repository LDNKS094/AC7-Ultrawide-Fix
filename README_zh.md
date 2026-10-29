# AC7 超宽屏修复

[English](README.md) | 中文

为《皇牌空战 7》扩展超宽分辨率下的 3D 视野，并修正 HUD、字幕、确认框、加载页的比例与位置。安装后自动生效。

安装方式可选**脚本安装**或**手动安装**。

## 工作原理

- **3D 视野**：按实际视口宽高比调整相机投影，在保持垂直视野的同时扩展水平视野，超宽屏显示更多两侧场景。
- **HUD**：调整原 HUD 着色器的横向采样位置，使 HUD 居中并保持文字与图形比例。
- **界面布局**：脚本在界面创建与切换时调整字幕、确认框和加载页的最终画布，按 16:9 居中。

修正均于游戏运行时生效，不修改游戏 EXE 或资源文件。3D 与 UI 按视口计算，不限固定分辨率；HUD 按启动时主显示器的比例计算。

## 安装

### 前置依赖

| 依赖 | 说明 |
| --- | --- |
| [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases)（x64） | 用于加载两个 ASI |
| [UE4SS](https://www.nexusmods.com/acecombat7skiesunknown/mods/2474)（含 UEHelpers） | 用于加载 UI 脚本 |

依赖需自行安装配置。

在游戏根目录，即包含 `Ace7Game.exe` 的目录，其结构应该是：

```text
ACE COMBAT 7/
  Ace7Game.exe
  dinput8.dll            ASI Loader
  dwmapi.dll             UE4SS 加载器
  ue4ss/
    UE4SS.dll
    UE4SS-settings.ini
    Mods/shared/UEHelpers/UEHelpers.lua
```

### 脚本安装

1. 安装前置依赖。
2. 运行 `Install.cmd`。

安装脚本会自动查找游戏安装目录，检查 UE4SS/UEHelpers 路径、复制 ASI 与 Lua，并合并模组列表。

找不到时手动指定游戏目录：

```powershell
.\Install.cmd -GameDirectory 'D:\Games\ACE COMBAT 7'
```

### 脚本卸载

运行 `Uninstall.cmd`，自动移除本补丁直接添加的文件与模组列表条目。

需要指定目录时：

```powershell
.\Uninstall.cmd -GameDirectory 'G:\Games\ACE COMBAT 7'
```

### 手动安装

1. 安装前置依赖。
2. 复制模组文件：

| 本包文件 | 复制到 |
| --- | --- |
| `payload/AC7SceneProjection.asi` | 游戏根目录 |
| `payload/AC7HUDCenter.asi` | 游戏根目录 |
| `mod/AC7UIAspect/` | `ue4ss/Mods/AC7UIAspect/` |

3. 在 `ue4ss/Mods/mods.txt` 中添加：

```text
AC7UIAspect : 1
```

4. 在 `ue4ss/Mods/mods.json` 中添加：

```json
[
  { "mod_name": "AC7UIAspect", "mod_enabled": true }
]
```

### 手动卸载

退出游戏，删除以下文件与目录：

- `AC7SceneProjection.asi`
- `AC7HUDCenter.asi`
- `AC7SceneProjection.log`、`AC7HUDCenter.log`（若存在）
- `ue4ss/Mods/AC7UIAspect/`

再从 `ue4ss/Mods/mods.txt` 与 `ue4ss/Mods/mods.json` 中删除 `AC7UIAspect` 条目。

前置依赖若仍被其他模组使用则无需删除。

## 从源码构建

环境：Visual Studio 2022 的 x64 MSVC、Windows SDK 与 CMake。

在项目根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

产物：

```text
payload/
  AC7SceneProjection.asi
  AC7HUDCenter.asi
```

编译后即可按照常规安装方式使用。

## 许可证

本项目以 [GPL-3.0](LICENSE) 发布。随包的第三方组件保留各自的许可证。
