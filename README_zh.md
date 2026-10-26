# AC7 超宽屏修复

[English](README.md) | 中文

为《皇牌空战 7》扩展超宽分辨率下的 3D 视野，并修正 HUD、字幕、确认框、加载页的比例与位置。安装后自动生效。

安装方式二选一：**脚本安装**（`Install.cmd`）或**手动安装**，两者放入游戏的文件相同。

## 修复内容

- **3D**：按实际视口扩展水平视野。
- **HUD**：保留原着色器，校正横向偏移。

3D 与 UI 按视口计算，不限固定分辨率；HUD 按启动时主显示器的比例计算。

## 前置依赖

| 依赖 | 说明 |
| --- | --- |
| [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases)（x64） | 用于加载两个 ASI |
| [UE4SS](https://www.nexusmods.com/acecombat7skiesunknown/mods/2474)（含 UEHelpers） | 用于加载 UI 脚本 |
| [VC++ 2015–2022 x64 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe) | ASI 运行所需 |

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

## 方式一：脚本安装

1. 安装上述外部依赖。
2. 解压本补丁，运行 `Install.cmd`。
3. 从 Steam 启动游戏。

安装器会自动查找 Steam 库；找不到时手动指定游戏目录：

```powershell
.\Install.cmd -GameDirectory 'D:\Games\ACE COMBAT 7'
```

安装器会校验补丁文件、检查 UE4SS/UEHelpers 路径、复制 ASI 与 Lua，并合并模组列表。

### 卸载

运行 `Uninstall.cmd`，仅移除本补丁直接添加的文件与模组列表条目。

需要指定目录时：

```powershell
.\Uninstall.cmd -GameDirectory 'G:\Games\ACE COMBAT 7'
```

## 方式二：手动安装

1. 退出游戏，装好上述依赖。
2. 复制补丁文件：

| 本包文件 | 复制到 |
| --- | --- |
| `payload/AC7SceneProjection.asi` | 游戏根目录 |
| `payload/AC7HUDCenter.asi` | 游戏根目录 |
| `mod/AC7UIAspect/` | `ue4ss/Mods/AC7UIAspect/` |

3. 在 `ue4ss/Mods/mods.txt` 中添加或更新（保留其他条目）：

```text
AC7UIAspect : 1
```

4. 在 `ue4ss/Mods/mods.json` 中添加或更新条目：

```json
[
  { "mod_name": "AC7UIAspect", "mod_enabled": true }
]
```

5. 从 Steam 启动游戏。

### 手动卸载

退出游戏，删除以下文件与目录：

- `AC7SceneProjection.asi`
- `AC7HUDCenter.asi`
- `AC7SceneProjection.log`、`AC7HUDCenter.log`（若存在）
- `ue4ss/Mods/AC7UIAspect/`

再从 `ue4ss/Mods/mods.txt` 与 `ue4ss/Mods/mods.json` 中删除 `AC7UIAspect` 条目。

外部依赖若仍被其他模组使用则无需删除。

## 从源码构建

环境：Windows x64，Visual Studio 2022（或 Build Tools）带“使用 C++ 的桌面开发”工作负载与 Windows SDK，CMake 3.20+。

在项目根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1
```

脚本会配置 x64 工程并以 Release 编译。

产物：

```text
payload/
  AC7SceneProjection.asi
  AC7HUDCenter.asi
```

编译后即可按照常规安装方式使用。