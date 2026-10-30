# Veymora Survivors — Итоговый отчёт об интеграции с платформой Яндекс Игры

## 1. Введение и общий статус готовности

Проект **Veymora Survivors** (версия **0.3**, движок **Godot Engine 4.6.2**, целевая платформа **Web / GL Compatibility WebGL2**) прошел полный цикл платформенной интеграции с сервисами **Яндекс Игр** и пост-аудиторную стабилизацию.

Кодовая база полностью подготовлена к загрузке в консоль разработчика и публикации для десктопных и мобильных браузеров. При этом архитектура гарантирует 100% автономную работоспособность проекта в локальном режиме и редакторе без внешних зависимостей.

---

## 2. Матрица статусов реализации компонентов

Все требования и исправленные замечания классифицированы по стандартизированным статусам:
- `[IMPLEMENTED]` — полностью реализовано в коде проекта.
- `[AUTOMATED_TESTED]` — подтверждено автоматизированными тестами проекта (все 14 тестовых сьютов пройдены без ошибок).
- `[BROWSER_TESTED]` — протестировано локально в браузерном окружении.
- `[CONSOLE_CONFIGURED]` — требует ручной конфигурации параметров в консоли разработчика.
- `[YANDEX_TESTED]` / `[NOT_VERIFIED]` — ожидает загрузки черновика zip-архива и проверки на платформе.

| Задача / Подсистема | Статус | Подтверждение / Файлы |
|---|---|---|
| **P0.1: Loading API и гонки инициализации** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/platform/yandex_games_bridge.gd`<br>`scripts/ui/main_menu.gd`<br>`tests/test_yandex_integration.gd` |
| **P0.2: Сквозной цикл облачных сохранений** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/game/save_manager.gd`<br>`scripts/ui/main_menu.gd`<br>`tests/test_yandex_integration.gd` |
| **P0.3: Централизованный Gameplay API** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/platform/yandex_games_bridge.gd`<br>`scripts/game/game_flow_controller.gd`<br>`tests/test_yandex_integration.gd` |
| **P0.4: Многофакторная пауза и звук** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/game/pause_manager.gd`<br>`scripts/audio/audio_manager.gd`<br>`tests/test_yandex_integration.gd` |
| **P0.5: Персистентность настроек языка** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/game/save_manager.gd`<br>`scripts/game/localization_manager.gd`<br>`tests/test_yandex_integration.gd` |
| **P0.6: Сессионная изоляция рекламы** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/platform/yandex_games_bridge.gd`<br>`scripts/ui/second_chance_dialog.gd`<br>`tests/test_yandex_integration.gd` |
| **P1.7: 100% паритет локализации интерфейса** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/game/localization_manager.gd`<br>`scripts/ui/results_screen.gd`<br>`tests/test_yandex_integration.gd` |
| **P1.8: Мобильный тач и джойстик** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/ui/virtual_joystick.gd`<br>`scripts/ui/hud_controller.gd`<br>`tests/test_yandex_integration.gd` |
| **P1.9: Защитный кулдаун Interstitial** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `scripts/platform/yandex_games_bridge.gd`<br>`scripts/ui/results_screen.gd`<br>`tests/test_yandex_integration.gd` |
| **P1.10: Таблица лидеров `rift_explorers`** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[CONSOLE_CONFIGURED: NOT_VERIFIED]` | `scripts/platform/yandex_games_bridge.gd`<br>`scripts/ui/results_screen.gd`<br>`tests/test_yandex_integration.gd` |
| **P2.13: Реалистичность документации** | `[IMPLEMENTED]` | `docs/YANDEX_GAMES_AUDIT.md`<br>`docs/YANDEX_GAMES_RELEASE_CHECKLIST.md`<br>`docs/YANDEX_GAMES_INTEGRATION_REPORT.md` |
| **P2.14: Однопоточный Web-экспорт** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]`<br>`[BROWSER_TESTED]` | `export_presets.cfg`<br>`build/web/index.html` (38.5 МБ < 100 МБ) |
| **P2.15: Сьют граничных случаев платформы** | `[IMPLEMENTED]`<br>`[AUTOMATED_TESTED]` | `tests/test_yandex_integration.gd` (22 сценария) |
| **Проверка на живой платформе Яндекс Игр** | `[NOT_VERIFIED]` | Ожидает загрузки zip-архива разработчиком в консоль |

---

## 3. Архитектурный обзор ключевых доработок

### 3.1. Устранение гонок Loading API и готовности игры (P0.1)
- Введена строгая двухфазная модель готовности:
  - `is_game_ready` выставляется в `MainMenu._ready()` после построения всех стартовых нод.
  - `is_sdk_initialized` выставляется при завершении `YaGames.init()`.
- Вызов `ysdk.features.LoadingAPI.ready()` производится строго один раз при одновременной истинности обоих флагов через метод `_check_and_send_loading_ready()`.
- Инициализация защищена таймаутом (4000 мс в JS, 5.0 с в GDScript). Получение данных игрока защищено через `Promise.race()` с таймаутом 2000 мс, что полностью исключает зависание экрана загрузки при проблемах со связью.

### 3.2. Сквозной цикл облачных сохранений (P0.2)
- При инициализации и после авторизации данные загружаются из облака через `ysdk.getPlayer().getData()`.
- Алгоритм слияния `SaveManager.merge_with_cloud(cloud_data)`:
  - Пустое облако никогда не затирает локальный прогресс.
  - Арены объединяются (множество Union).
  - Рекорды времени, убийств и побежденных боссов берутся по максимуму `max(local, cloud)`.
  - Открытия Кодекса и Атласа объединяются без дубликатов.
  - Результат слияния немедленно сохраняется в локальное хранилище (`user://save_data.json`).
- Механизм отложенного сохранения (`schedule_cloud_save()` с дебаунсом 1.5 с) снижает нагрузку на сеть, а метод `flush_cloud_save()` гарантирует запись при закрытии сессии.
- В `MainMenu` добавлен блок управления аккаунтом: отображение имени игрока / статуса гостя и кнопка авторизации.

### 3.3. Централизованная синхронизация Gameplay API (P0.3)
- Синхронизация состояний геймплея объединена в `YandexGamesBridge.reconcile_gameplay_state()`.
- Целевое состояние:
  $$\text{target\_active} = (\text{GameFlowController.current\_state} == \text{STATE\_PLAYING}) \land \neg \text{PauseManager.is\_paused()}$$
- Исключены любые паразитные вызовы старта/остановки: порядок в `GameFlowController` изменен так, что сначала меняется состояние игры, и только затем очищаются флаги паузы.

### 3.4. Многофакторный менеджер паузы и управление звуком (P0.4)
- Внедрен независимый побитовый реестр причин паузы (`REASON_USER`, `REASON_BROWSER_FOCUS`, `REASON_PLATFORM`, `REASON_ADVERTISEMENT`, `REASON_MODAL`).
- При ручной паузе или потере фокуса окна браузера:
  - Мастер-шина приглушается (`AudioServer.set_bus_mute(0, true)`).
  - Все звучащие звуковые эффекты мгновенно останавливаются (`AudioManager.stop_all_sfx()`).
- Звук включается обратно строго тогда, когда сняты абсолютно все активные причины паузы. Пользовательские настройки громкости не сбрасываются.

### 3.5. Персистентность языка и 100% паритет словарей (P0.5, P1.7)
- Настройки языка (`language`, `user_selected_language`) включены в схему сохранений `SaveManager` и защищены от перезаписи при автоопределении SDK.
- В `LocalizationManager` обеспечен 100% паритет ключей между словарями `ru` и `en`:
  - 105 ключей в каждом словаре.
  - 0 отсутствующих ключей.
  - 0 пустых строк.
- Все жестко зашитые русские строки в `ResultsScreen`, `ArchiveDialog`, `HUDController` и обучающих подсказках заменены на локализованные ключи.

### 3.6. Сессионная изоляция рекламы (P0.6, P1.9)
- Каждая попытка показа рекламы инициирует уникальную сессию с `session_id`.
- Колбэки `onOpen`, `onClose`, `onError`, `onRewarded` проверяют валидность ID сессии; запоздалые или посторонние вызовы игнорируются.
- Механика «Второй шанс» выдает возрождение мага строго при подтверждении колбэка `onRewarded`.
- Кнопки навигации блокируются от повторных кликов (`_is_navigating`), а между показами межстраничной рекламы действует кулдаун в 65 секунд.

### 3.7. Мобильная адаптация и виртуальный джойстик (P1.8)
- Сенсорный джойстик и мобильная кнопка паузы отображаются строго на сенсорных / мобильных устройствах (`is_mobile or is_touch`) и скрыты на Desktop Web.
- Добавлена корректная обработка сворачивания окна (`NOTIFICATION_APPLICATION_FOCUS_OUT`) со сбросом вектора ввода.
- В шаблон экспорта внедрены CSS-правила блокировки жестов браузера (`touch-action: none`, `user-select: none`).

### 3.8. Таблица лидеров «rift_explorers» (P1.10)
- Расчет очков забега: $\text{Score} = \text{Time} \times 10 + \text{Kills} \times 5$.
- Дополнительные метаданные (`arena`, `synergies`, `level`) сериализуются в безопасный JSON-формат.
- Вызовы `submit_score()` устойчивы к отсутствию авторизации или сетевым ошибкам.

---

## 4. Результаты автоматизированного тестирования

В проекте запущен полный набор автоматических тестов в headless-режиме Godot 4.6.2:

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

Специализированный набор тестов `test_yandex_integration.gd` включает 22 проверочных сценария, в том числе:
- Гонка готовности (игра готова раньше SDK, SDK готово раньше игры).
- Таймаут получения игрока и fallback в гостевой режим.
- Защита ручного выбора языка от перезаписи автоопределением SDK.
- Изоляция сессий рекламы и отклонение некорректных колбэков.
- Приоритет причин паузы и глушение аудиошины.
- Полное совпадение ключей словарей RU/EN.
- Дебаунсинг и слияние облачных сохранений.

---

## 5. Метрики релизного Web-экспорта

Экспорт выполнен с помощью команды:
```bash
Godot_v4.6.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html
```

### Фактические размеры артефактов сборки:
- **`index.wasm`:** 37 695 054 байт (~37.7 МБ)
- **`index.pck`:** 505 440 байт (~505 КБ)
- **`index.js`:** 315 759 байт (~315 КБ)
- **`index.html`:** 4 105 байт (~4 КБ)
- **`index.icon.png` / `index.apple-touch-icon.png`:** ~4 КБ
- **Суммарный вес сборки:** **~38.5 МБ**

**Норматив платформы Яндекс Игры:** до 100 МБ.  
Запас по размеру составляет более 61 МБ (~61.5%).  
Все пути к файлам в `index.html` являются строго относительными. Файл `index.html` находится в корне сборки.

---

## 6. Руководство по настройке в Консоли разработчика Яндекс Игр

Перед отправкой сборки на модерацию разработчику необходимо настроить в консоли:

### 6.1. Настройка Таблицы лидеров:
- **Название лидерборда:** «Лучшие исследователи Разлома» (RU) / "Best Rift Explorers" (EN)
- **Техническое имя:** `rift_explorers` *(обязательно строчными буквами с подчеркиванием)*
- **Тип очков:** Числовой (`numeric`)
- **Порядок сортировки:** По убыванию (`descending`)
- **Количество знаков после запятой:** 0

### 6.2. Настройка рекламы:
- Включить межстраничный формат (Fullscreen / Interstitial).
- Включить формат с вознаграждением (Rewarded Video).
- Убедиться, что системные ограничения интервалов рекламы согласованы с внутриигровым кулдауном (65 секунд).

### 6.3. Мобильные настройки и ориентация:
- Установить поддерживаемую ориентацию: **Альбомная (Landscape)**.
- Указать поддержку платформ: **Десктоп**, **Мобильные**, **Планшеты**.

### 6.4. Загрузка черновика и модерация:
1. Запаковать содержимое папки `build/web/` в zip-архив (файлы `index.html`, `index.js`, `index.wasm`, `index.pck` должны лежать непосредственно в корне архива).
2. Загрузить zip-архив в раздел «Исходный файл игры» черновика.
3. Проверить в тестовом фрейме консоли корректность работы рекламы и сохранений.
4. Отправить заявку на модерацию.
