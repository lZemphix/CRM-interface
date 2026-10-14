# Автоматические desktop-сборки

Pipeline: `.github/workflows/desktop-release.yml`. Linux, Intel Mac, установщики,
автообновление клиента, backend и развёртывание сервера в этот этап не входят.

## Что запускается

- Push в `main` и pull request: проверка реестра модулей, анализатор, тесты release-инструментов
  и один полный `flutter test`. Бинарники не публикуются.
- Публикация GitHub Release (`release: published`, включая prerelease): проверки,
  затем параллельные сборки Windows и Mac. Только после успеха обоих заданий
  отдельное задание прикрепляет файлы к уже существующему релизу.
- Actions → Desktop checks and release → Run workflow: проверки и обе сборки,
  ZIP доступны в Artifacts этого запуска на 14 дней. Release не создаётся и не меняется.

Все задания работают на Windows или macOS, без Linux runner. Для Windows выбран
`windows-2022` (x64), для Apple Silicon — `macos-15` (arm64, дополнительно проверяется).
macOS использует `FLUTTER_MACOS_ARM64_ONLY=true`; архитектура основного executable
проверяется через `lipo`. Существующие Windows/macOS проекты не пересоздаются.

## Как выпустить релиз

1. Установить версию в `pubspec.yaml`, например `1.2.3+4` или `1.2.3-rc.1+4`.
   Здесь `+4` — номер сборки; prerelease `rc.1` — часть версии.
2. Закоммитить и запушить все нужные исходники вместе с актуальным реестром модулей.
   Workflow обязан находиться в публикуемой версии и в основной ветке для ручного запуска.
3. На GitHub открыть Releases → Draft a new release. Выбрать нужный commit и тег
   **`v1.2.3`** либо **`v1.2.3-rc.1`**, без номера сборки `+4`.
4. Нажать Publish release. Сохранение draft само по себе pipeline не запускает.
5. Дождаться зелёного запуска Actions. В опубликованном релизе сначала может не быть файлов:
   они появляются после завершения сборок, а не сразу после нажатия Publish.

Тег должен в точности совпасть с версией `pubspec.yaml` (с префиксом `v`, без `+build`).
Несовпадение останавливает процесс до сборок; CI не переписывает версию автоматически.
Доступ к Actions, разрешённые используемые actions и квоты аккаунта проверяются
в настройках GitHub. Нужен обычный `GITHUB_TOKEN`, персональный PAT не требуется.

Результат:

```text
CRM-interface-v1.2.3-windows-x64.zip
CRM-interface-v1.2.3-macos-arm64.zip
SHA256SUMS.txt
build-info.json
```

`SHA256SUMS.txt` содержит SHA-256 обоих ZIP; `build-info.json` — версию, номер сборки,
Flutter SDK, исходный commit и отметку об отсутствии notarization.
Контрольная сумма обнаруживает изменение файла, но не заменяет подпись издателя.
Перед публикацией проверяются наличие ровно двух ожидаемых ZIP и их целостность.

## Windows 10/11 x64

ZIP содержит весь Release bundle: `crm_interface.exe`, Flutter/plugin DLL, `data`
с AOT и assets, release x64 DLL Visual C++ из redist установленного Visual Studio.
Упаковщик проверяет PE-архитектуру executable и добавляемого runtime.
Отдельный `.exe` без остальных файлов не является дистрибутивом.

Получатель распаковывает всю папку `CRM-interface` и запускает `crm_interface.exe`.
Flutter/Visual Studio устанавливать не нужно. Это portable ZIP без Windows code signing,
поэтому возможен SmartScreen. На чистых Windows 10 и 11 требуется ручной smoke test:
запуск, вход, запись refresh-токена, обновление сессии, выход.
Сборка на Windows Server runner сама по себе не доказывает эти сценарии.
Microsoft runtime распространяется на условиях Microsoft; права на наши исходники
и итоговый продукт определяются отдельно, CI новую лицензию не вводит.

## macOS Apple Silicon

В ZIP находится `CRM-interface.app`, скрипт запуска с адресом API и инструкция.
Используется существующий `scripts/build_macos_release.sh`; `ditto` сохраняет
структуру `.app`, symlink и метаданные. Версионное имя ZIP добавляет `scripts/release.py`.
Проверяются архитектура, `codesign --verify --deep --strict` и release entitlements
(sandbox, клиентская сеть; debugger access не разрешён).

Это **ad-hoc подпись**, не Developer ID, не notarization и не доверие Gatekeeper.
Никакие сертификаты, Apple-аккаунты или ключи в GitHub Secrets сейчас не нужны.
CI не отключает Gatekeeper и не снимает карантин. На доверенной сборке может понадобиться
точечное разрешение «Всё равно открыть»; невозможность запуска требует диагностики,
а не глобального отключения защиты. См. [инструкцию macOS](macos.md).

Первую скачанную сборку нужно проверить на реальном Mac: запуск, сеть,
сохранение refresh-токена в Keychain, refresh, выход и поведение после обновления `.app`.
Проверка подписи в CI не заменяет эти сценарии и не гарантирует доступ к старым
Keychain-записям при смене identity. Bundle ID и auth-логику этот этап не меняет.

## Адрес backend и секреты

Сборки не включают БД, аккаунты, токены или `.env`. Backend устанавливается отдельно.
Адрес по умолчанию — `http://127.0.0.1:8000`; адрес другого сервера можно передать
готовому клиенту через `--api-url=https://crm.example.org`. Пример домена нужно заменить.
Windows: `.\crm_interface.exe --api-url=https://crm.example.org` в PowerShell.
Mac: `./"Запустить CRM.command" https://crm.example.org` в каталоге распакованного ZIP.
Внешнее подключение требует HTTPS; HTTP оставлен для локальной разработки.

## Закрепление версий и безопасный повтор

Flutter закреплён в `.flutter-version` (3.47.2, Dart 3.13.2), который соответствует
текущей проверенной Windows-среде. Зависимости устанавливаются с `--enforce-lockfile`.
Обновление SDK — отдельное изменение с проверкой обеих платформ, не плавающий `stable`.
Используемые внешние actions закреплены на commit SHA. По умолчанию токен имеет
`contents: read`; `contents: write` есть только у publish, недоступного PR/ручному запуску.
Checkout не оставляет credentials в локальном git config.

Пакеты не перезаписываются молча: нет `--clobber`, локальные упаковщики тоже
отказываются заменять существующий версионный ZIP. При неудачной сборке можно
повторить failed jobs. Если загрузка файлов оборвалась после частичного успеха,
сначала проверить Assets релиза: повтор публикации может упереться в уже загруженные
имена. Не удалять/заменять выданный пользователям релиз вслепую; предпочтителен новый тег.
Загрузка нескольких GitHub Assets не является атомарной транзакцией.

## Локальная проверка

```powershell
python scripts/release.py metadata --tag v1.0.0
python -m unittest discover -s scripts/tests -v
flutter pub get --enforce-lockfile
dart run tool/generate_modules.dart --check
dart analyze lib test tool
dart run tool/flutter.dart test
dart run tool/flutter.dart build windows --release
.\scripts\package_windows.ps1
```

В примере тег `v1.0.0` подходит только к текущему `pubspec.yaml`; при смене версии
замените его. Скрипт PowerShell ищет release x64 CRT через Visual Studio `vswhere`;
можно явно передать `-RuntimeDirectory` с каталогом `Microsoft.VC*.CRT`.
Для повторной локальной упаковки используйте чистый рабочий каталог: ранее созданный
версионный ZIP специально не заменяется автоматически.

На Mac перед версионной упаковкой:

```bash
FLUTTER_MACOS_ARM64_ONLY=true bash scripts/build_macos_release.sh
python3 scripts/release.py macos
```

Для ручной сборки без Apple-сертификата не должно быть `Signing.local.xcconfig`;
существующий личный файл не удаляйте автоматически. Его использование — отдельный
локальный режим, не проверка CI. Реальный pipeline можно подтвердить только запуском
на GitHub после коммита/пуша; создание этих файлов не означает, что Actions уже отработал.

Источники: [GitHub release events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release),
[runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[Flutter desktop targets](https://docs.flutter.dev/reference/supported-platforms),
[Apple Gatekeeper](https://support.apple.com/en-ie/102445).
