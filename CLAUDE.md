# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

MyRadio — это macOS-приложение (SwiftUI), созданное в Xcode 26.4.1. Цель — клиент для интернет-радио на основе каталога [radio-browser.info](https://www.radio-browser.info/), доступ к которому идёт через Swift package `RadioBrowserKit`.

## Build / run / test

Только один target — `MyRadio` (macOS app). Схема лежит в `xcuserdata`, в общий доступ не выложена.

```bash
# Build (Debug, native arch)
xcodebuild -project MyRadio.xcodeproj -scheme MyRadio -configuration Debug build

# Сборка через xcrun + open (запуск .app)
xcodebuild -project MyRadio.xcodeproj -scheme MyRadio -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/MyRadio.app

# Чистая сборка
xcodebuild -project MyRadio.xcodeproj -scheme MyRadio clean build

# Тесты — пока test target не заведён, команда упадёт с "scheme has no test action"
# xcodebuild -project MyRadio.xcodeproj -scheme MyRadio test
```

Для разовой проверки одного Swift-файла без полной сборки:
```bash
xcrun -sdk macosx swiftc -parse <path/to/File.swift>
```

## Архитектурные особенности

### PBXFileSystemSynchronizedRootGroup

Папка `MyRadio/` подключена через `PBXFileSystemSynchronizedRootGroup` (objectVersion=77, фича Xcode 16+). Это значит:

- **Любой `*.swift` или ресурс, добавленный в `MyRadio/`, автоматически попадает в target.** Не нужно править `project.pbxproj`, не нужно `Add Files to…` через Xcode UI.
- Удалить файл из target = просто удалить файл с диска.
- Это сильно упрощает работу из CLI/Claude Code: создавайте файлы напрямую через `Write`, никаких pbxproj-патчей.

### Build configuration

- `SDKROOT = macosx`, `MACOSX_DEPLOYMENT_TARGET = 26.4` — целятся в актуальный macOS, других платформ (iOS/visionOS) у target нет.
- `SWIFT_VERSION = 5.0`.
- `GENERATE_INFOPLIST_FILE = YES` — Info.plist не существует как файл, ключи задаются через build settings (`INFOPLIST_KEY_*`). Если потребуется добавить что-то нетривиальное (entitlements, capabilities), используйте либо новые `INFOPLIST_KEY_*`, либо отдельный `Info.plist` + `INFOPLIST_FILE`.
- `PRODUCT_BUNDLE_IDENTIFIER = ru.korenskoy.MyRadio`, team `UZEE5BVAH9`, `CODE_SIGN_STYLE = Automatic`.

### Зависимости (SwiftPM)

Один package, подключённый через Xcode (`Package.resolved` лежит в `MyRadio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`):

- **RadioBrowserKit** — `https://github.com/PankajGaikar/RadioBrowserKit.git`, pin v0.0.1 (revision `b0f0aced…`). Клиент Radio-Browser API; через него ожидается получение списка станций/поиск/тегов. Документацию смотрите в репозитории пакета — версия 0.0.1, API может быть нестабильным.

Резолюция управляется Xcode (Package Manager → Update to Latest Package Versions). Из CLI:
```bash
xcodebuild -resolvePackageDependencies -project MyRadio.xcodeproj
```

## Конвенции

- App entrypoint — `@main struct MyRadioApp: App` в `MyRadio/App/MyRadioApp.swift`.
- Главное окно — SwiftUI `WindowGroup`. Для воспроизведения аудио на macOS вероятно понадобится `AVFoundation` / `AVPlayer` поверх станций из `RadioBrowserKit`.
- Ассеты (icons, accent color) — только через `Assets.xcassets`.

## Локализация

String Catalog (`MyRadio/Localizable.xcstrings`) управляется **только** через `scripts/add-l10n.sh` и `scripts/remove-l10n.sh`. Не редактируйте `.xcstrings` руками — скрипты сделаны специально, чтобы не гонять JSON-каталог через Read/Edit на каждое изменение.

```bash
# Добавить/обновить ключ. KEY = английский source; не переданные локали не создаются.
./scripts/add-l10n.sh "Source English text" \
  --comment "Where it appears" \
  --ru "Перевод" --de "Übersetzung" --az "Tərcümə"

# Дозалить локали к существующему ключу — повторный вызов с другим набором флагов.
./scripts/add-l10n.sh "Source English text" --fr "Traduction"

# Снести один язык (исходную локаль `en` индивидуально удалить нельзя):
./scripts/remove-l10n.sh "Source English text" --locale ru

# Снести ключ целиком:
./scripts/remove-l10n.sh "Source English text"
```

- Catalog лежит по `MyRadio/Localizable.xcstrings`, подцеплен в target автоматически через `PBXFileSystemSynchronizedRootGroup`.
- Поддерживаемые языки приложения заданы в `MyRadio/Models/AppLanguage.swift`: `en, ru, de, fr, es, az, ja, zh`. Скрипт не валидирует — можно передать любую BCP-47 локаль, но catalog лучше держать синхронным с пикером в Preferences → General.
- Внутри обёрток — `scripts/_l10n.py`. Для нестандартной мутации расширяйте Python-модуль, не байпасьте через ручной edit.
- В тестах/одноразовых проверках перенаправляйте каталог через env: `MYRADIO_CATALOG_PATH=/tmp/test.xcstrings ./scripts/add-l10n.sh ...`.
