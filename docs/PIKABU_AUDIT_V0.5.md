# Veymora Survivors 0.5 — Pikabu Edition & GamePush Integration Audit

**Date:** 01.11.2026  
**Target Engine:** Godot 4.6.x (Compatibility / WebGL2, Single-Threaded)  
**Target Platform:** Web (Pikabu Games / GamePush SDK & Yandex Games Dual-Target)  

---

## 1. Project Structure & Dependencies Audit

### 1.1 Configuration Files
* **`project.godot`:**
  * Autoloads currently configured:
    * `GameFlow="*res://scripts/game/game_flow_controller.gd"`
    * `PauseMgr="*res://scripts/game/pause_manager.gd"`
    * `LocMgr="*res://scripts/game/localization_manager.gd"`
    * `YandexBridge="*res://scripts/platform/yandex_games_bridge.gd"`
  * Window size: 1280x720, stretch mode `canvas_items`, aspect `keep`.
  * Rendering: GL Compatibility (`renderer/rendering_method="gl_compatibility"`, mobile="gl_compatibility").
* **`export_presets.cfg`:**
  * Preset 0: `Web` (`build/web/index.html`), `variant/thread_support=false`, `variant/extensions_support=false`.
  * Currently injects `<script src="https://yandex.ru/games/sdk/v2"></script>` in `html/head_include`.
  * Needs dedicated presets or adaptive shell/export configuration for Pikabu / GamePush export without breaking Yandex export.

### 1.2 Platform Bridge (`YandexGamesBridge`)
* Singleton node with robust ad lifecycle management, modal pauses, debounced cloud saves, score submission, and local fallback.
* Direct callers:
  * `scripts/game/game_flow_controller.gd`
  * `scripts/game/save_manager.gd`
  * `scripts/ui/hud_controller.gd`
  * `scripts/ui/main_menu.gd`
  * `scripts/ui/results_screen.gd`
  * `scripts/ui/second_chance_dialog.gd`
  * `tests/test_yandex_integration.gd`
* *Requirement:* Preserve `YandexGamesBridge` without regression while unifying calls under `PlatformManager`.

### 1.3 Save Manager (`SaveManager`)
* Schema Version: 2 (`CURRENT_VERSION = 2`).
* Cloud merge logic: `SaveManager.merge_with_cloud(cloud_raw, base_local_data)` already handles max metrics, union of unlocked arenas, union of discovered spells/synergies/evolutions/artifacts/atlas goals, and deduplication of 10 recent run histories.
* Save trigger: `SaveManager.save_custom_data` schedules cloud saves through `schedule_cloud_save()`. Needs to interface with `PlatformManager`.

### 1.4 Audio & Pause Management (`PauseManager`, `AudioManager`)
* `PauseManager` maintains a multi-reason dictionary (`REASON_USER`, `REASON_BROWSER_FOCUS`, `REASON_PLATFORM`, `REASON_ADVERTISEMENT`, `REASON_MODAL`).
* Safely keeps user pause active if browser focus returns or ads finish.
* `AudioManager` provides `set_temporary_mute(muted)` which stops active SFX and mutes the Master bus.

### 1.5 Mobile Controls & Input
* `VirtualJoystick` (`scripts/ui/virtual_joystick.gd`) supports multitouch, mouse emulation, vector clamping, and deadzone.
* `HUDController` toggles joystick visibility based on device detection.
* Menus need touch validation on extreme aspect ratios (e.g. 19.5:9, 20.5:9, 4:3).

### 1.6 Official GamePush Plugin
* Official plugin from `GamePushService/GamePush-Godot-plugin` (v2.0.2) inspected.
* Exposes `GP` singleton with modules `ads`, `player`, `storage`, `game`, `platform`, `device`, `language`, `leaderboard`.
* Identified fix required in `addons/gamepush/game_push.gd`:
  * Operator precedence error `if !OS.get_name() == "Web":` evaluates `(!OS.get_name()) == "Web"` which fails on Windows desktop/headless and crashes on `JavaScriptBridge.get_interface("window")`.
  * Fix applied: `if OS.get_name() != "Web" or not Engine.has_singleton("JavaScriptBridge"):`.
  * Timeout guard added to avoid infinite `while not gp:` loops when SDK is blocked or offline.

---

## 2. Inventory of Required Changes

| Area | File Path | Action | Description |
|------|-----------|--------|-------------|
| **Platform** | `scripts/platform/base_platform_bridge.gd` | **CREATE** | Abstract base class defining common interface, state, and signals for all platforms. |
| **Platform** | `scripts/platform/local_platform_bridge.gd` | **CREATE** | Local offline adapter for desktop, editor, and offline web play. |
| **Platform** | `scripts/platform/gamepush_bridge.gd` | **CREATE** | GamePush adapter wrapping official SDK methods (`GP.ads`, `GP.player`, `GP.game`, `GP.storage`). |
| **Platform** | `scripts/platform/yandex_games_bridge.gd` | **MODIFY** | Inherit `BasePlatformBridge`, preserve all existing public API and callbacks for 100% backward compatibility. |
| **Platform** | `scripts/platform/platform_manager.gd` | **CREATE** | Unified platform coordinator autoload. Detects platform, manages active bridge, prevents duplicate SDK inits. |
| **Plugin** | `addons/gamepush/*` | **INSTALL** | Official GamePush Godot Plugin files with desktop crash fix and timeout guards. |
| **Config** | `project.godot` | **MODIFY** | Register `PlatformMgr` autoload, configure GamePush default settings. |
| **Config** | `export_presets.cfg` | **MODIFY** | Configure distinct export presets for Yandex and Pikabu / GamePush. |
| **Saves** | `scripts/game/save_manager.gd` | **MODIFY** | Delegate `schedule_cloud_save` to `PlatformManager` with fallback to `YandexBridge`. |
| **Flow** | `scripts/game/game_flow_controller.gd` | **MODIFY** | Route gameplay start/stop events through `PlatformManager`. |
| **UI** | `scripts/ui/main_menu.gd` | **MODIFY** | Connect auth state, cloud sync, and ready notifications via `PlatformManager`. |
| **UI** | `scripts/ui/second_chance_dialog.gd` | **MODIFY** | Route rewarded ad requests through `PlatformManager`. |
| **UI** | `scripts/ui/results_screen.gd` | **MODIFY** | Add post-run Rewarded Video bonus claim button, route interstitial navigation through `PlatformManager`. |
| **UI** | `scripts/ui/hud_controller.gd` | **MODIFY** | Check `PlatformManager.is_mobile()` for virtual joystick activation. |
| **Localization** | `scripts/game/localization_manager.gd` | **MODIFY** | Add localization strings for Results screen rewarded bonus and GamePush platform toasts. |
| **Media** | `media/store/*` | **CREATE** | Store promotional materials (Icon 1024x1024, Cover 1920x1080, 4 Screenshots 1280x720). |
| **Tests** | `tests/test_v05_pikabu.gd` | **CREATE** | Comprehensive test suite covering all 15 required scenarios. |
| **Packaging** | `build/gamepush_zip/*` | **CREATE** | Standalone ZIP archive with `index.html` at root for GamePush / Pikabu upload. |
