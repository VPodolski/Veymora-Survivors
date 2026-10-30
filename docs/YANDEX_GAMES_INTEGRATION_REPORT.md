# Veymora Survivors — Отчёт об интеграции с платформой Яндекс Игры

## 1. Обзор проделанной работы

В рамках подготовки проекта **Veymora Survivors 0.3** к релизу на платформе **Яндекс Игры** выполнена комплексная архитектурная и геймплейная интеграция платформенных сервисов для настольных и мобильных браузеров:

1. **Изолированный платформенный уровень (`YandexGamesBridge.gd`):**
   - Полная инкапсуляция обращений к `JavaScriptBridge` и глобальному объекту `window.ysdk`.
   - Автоматическое определение среды: Web vs Native/Editor, Desktop vs Mobile/Tablet.
   - Безопасный локальный режим (Local Fallback Mode) с корректной эмуляцией всех колбэков при запуске вне браузера или без SDK.
   - Защита от потери колбэков сборщиком мусора движка через удержание ссылок на `JavaScriptObject`.

2. **Жизненный цикл игры и API загрузки:**
   - `LoadingAPI.ready()` вызывается строго после завершения первичной загрузки ресурсов и отрисовки главного меню (`MainMenu._ready()` -> `_notify_game_ready()`).
   - `GameplayAPI.start()` вызывается при начале активного геймплея в `GameFlowController` (`STATE_PLAYING`).
   - `GameplayAPI.stop()` вызывается при выходе из боя: ручная пауза, открытие сундука/повышения уровня, гибель, победа, экран результатов, выбор арены.

3. **Многофакторная система паузы (`PauseManager.gd`):**
   - Раздельный учёт причин паузы (`REASON_USER`, `REASON_BROWSER_FOCUS`, `REASON_PLATFORM`, `REASON_ADVERTISEMENT`, `REASON_MODAL`).
   - Мьютекс снятия паузы: возвращение фокуса в окно (`window.onfocus`) снимает причину `BROWSER_FOCUS`, но не возобновляет бой, если игрок сам поставил игру на паузу (`REASON_USER`).
   - Временное приглушение звука (`set_temporary_mute`): при показе рекламы или потере фокуса окна звук глушится через мастер-шину (`AudioServer.set_bus_mute(0, true)`), не сбивая сохранённые настройки громкости игрока.

4. **Адаптация сохранений и облачная синхронизация (`SaveManager.gd`):**
   - Поддержка полноценной игры в гостевом режиме (Guest mode) с сохранением в `user://save_data.json` (IndexedDB).
   - Слияние данных (`merge_with_cloud`): объединение списков открытых арен (Union), объединение выполненных целей Атласа и открытий Кодекса, выбор максимальных значений для рекордов выживания, количества забегов и поверженных боссов (`max(local, cloud)`).
   - Защита от затирания: пустой или новый профиль в облаке никогда не перезаписывает локальный прогресс игрока.

5. **Монетизация (Реклама):**
   - **Межстраничная реклама (Interstitial):** интегрирована в переходы между игровыми сессиями (нажатие «Повторить забег», «Выбор арены» или «В главное меню» на экране результатов) с таймером кулдауна (60–90 сек).
   - **Реклама за вознаграждение (Rewarded):** механика «Второй шанс» при первой гибели мага за забег. Вознаграждение выдаётся **строго** по факту вызова колбэка `onRewarded`. При воскрешении игрок получает 50% HP, 2.5 сек неуязвимости и защитную ударную волну. Механика доступна строго один раз за забег.

6. **Мобильное сенсорное управление и адаптивность:**
   - Компонент виртуального джойстика (`VirtualJoystick.gd` / `.tscn`) в нижнем левом углу с ограничением радиуса и мёртвой зоной.
   - Сенсорная кнопка паузы «⏸» в правом верхнем углу интерфейса.
   - Оверлей предупреждения о смене ориентации (`OrientationWarning.gd` / `.tscn`), требующий повернуть устройство в альбомный режим.
   - CSS-блокировка нежелательных жестов браузера в `index.html`: `touch-action: none`, `user-select: none`, `-webkit-touch-callout: none`.

7. **Двуязычная локализация (RU / EN):**
   - Автоматическое определение языка через `ysdk.environment.i18n.lang` (русский для СНГ, английский для остальных стран).
   - Переключатель языка в окне Настроек (`SettingsDialog`).
   - Полная поддержка RU и EN во всех меню, подсказках, HUD, диалогах и экране результатов.

8. **Таблица лидеров (Leaderboard):**
   - Интеграция с лидербордом «Лучшие исследователи Разлома» (`rift_explorers`).
   - Комплексная формула очков: `время_выживания * 10 + убийства * 5`.
   - Автоматическая отправка результата при завершении забега.

---

## 2. Структура добавленных и изменённых файлов

| Файл | Назначение |
|---|---|
| `scripts/platform/yandex_games_bridge.gd` | Изолированный мост взаимодействия с Яндекс Играми SDK |
| `scripts/game/pause_manager.gd` | Менеджер причин паузы и временного приглушения звука |
| `scripts/game/localization_manager.gd` | Менеджер локализации (RU / EN) и централизованный словарь |
| `scripts/ui/virtual_joystick.gd` | Логика сенсорного джойстика перемещения |
| `scenes/ui/virtual_joystick.tscn` | Сцена сенсорного джойстика |
| `scripts/ui/second_chance_dialog.gd` | Логика окна воскрешения за Rewarded-рекламу |
| `scenes/ui/second_chance_dialog.tscn` | Сцена диалога второго шанса |
| `scripts/ui/orientation_warning.gd` | Логика предупреждения о повороте экрана |
| `scenes/ui/orientation_warning.tscn` | Сцена оверлея ориентации |
| `scripts/player/player_controller.gd` | Интеграция ввода от виртуального джойстика и метод `revive_second_chance` |
| `scripts/ui/hud_controller.gd` | Интеграция с `PauseManager`, запуск потока смерти с «Вторым шансом», мобильная пауза |
| `scenes/ui/hud.tscn` | Размещение джойстика, кнопки мобильной паузы, второго шанса и оверлея ориентации |
| `scripts/game/main.gd` | Связка `VirtualJoystick` с игроком, координация гибели |
| `scripts/game/game_flow_controller.gd` | Вызовы `GameplayAPI.start()` и `gameplay_stop()`, сброс паузы |
| `scripts/ui/main_menu.gd` | Вызов `LoadingAPI.ready()`, динамическая смена языка |
| `scripts/ui/settings_dialog.gd` | Кнопка смены языка (RU / EN), динамический перевод опций |
| `scenes/ui/settings_dialog.tscn` | Строка настройки языка в интерфейсе |
| `scripts/ui/results_screen.gd` | Interstitial-реклама при навигации, отправка очков в Leaderboard |
| `scripts/game/save_manager.gd` | Метод `merge_with_cloud` для безопасного объединения сохранений |
| `scripts/audio/audio_manager.gd` | Метод `set_temporary_mute` для временного приглушения без сброса настроек |
| `export_presets.cfg` | Конфигурация Web-экспорта: внедрение SDK скрипта и touch CSS |
| `build/web/index.html` | Собранная страница с поддержкой Яндекс SDK и мобильными стилями |
| `tests/test_yandex_integration.gd` | Комплексный автоматизированный тест всей интеграции с платформой |
| `docs/YANDEX_GAMES_AUDIT.md` | Документ предрелизного аудита архитектуры |
| `docs/YANDEX_GAMES_RELEASE_CHECKLIST.md` | Практический чек-лист проверки перед загрузкой в консоль разработчика |
| `docs/YANDEX_GAMES_INTEGRATION_REPORT.md` | Итоговый технический отчёт |

---

## 3. Результаты автоматизированного тестирования

Были запущены все 14 тестовых наборов проекта:
```
=== Running tests/test_stage1.gd === [PASS]
=== Running tests/test_stage2.gd === [PASS]
=== Running tests/test_stage3.gd === [PASS]
=== Running tests/test_stage4.gd === [PASS]
=== Running tests/test_stage5.gd === [PASS]
=== Running tests/test_stage6.gd === [PASS]
=== Running tests/test_evolution_firing.gd === [PASS]
=== Running tests/test_performance.gd === [PASS]
=== Running tests/test_code_review_regressions.gd === [PASS]
=== Running tests/test_v01_systems.gd === [PASS]
=== Running tests/test_chest_and_refinements.gd === [PASS]
=== Running tests/test_v02_synergies_and_effects.gd === [PASS]
=== Running tests/test_v03_game_flow.gd === [PASS]
=== Running tests/test_yandex_integration.gd === [PASS]
=== ALL 14 TEST SUITES PASSED CLEANLY! ===
```

### Метрики Web-сборки:
- **`index.wasm`:** 35.95 МБ (37 695 054 байт)
- **`index.pck`:** 473.02 КБ (484 372 байт)
- **`index.js`:** 308.35 КБ (315 759 байт)
- **Общий вес пакета:** **~38.5 МБ** (лимит Яндекс Игр: 100 МБ)
- **Частота кадров:** 144+ FPS при 120 активных врагах и множестве снарядов
