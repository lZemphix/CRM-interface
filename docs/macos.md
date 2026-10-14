# CRM для macOS: запуск и передача разработчику

## Что находится в архиве

- `CRM-interface.app` — самостоятельный Flutter Release-клиент; Flutter/Dart и Xcode на компьютере получателя не нужны.
- `Запустить CRM.command` — запуск с выбранным адресом backend.
- `README.md` — эта инструкция.

Распакуйте ZIP **на Mac**, затем перенесите всю папку `CRM-macos` в удобное место.
Приложение предназначено для macOS 12+. Архивы GitHub Actions с суффиксом
`macos-arm64` рассчитаны только на Apple Silicon (M-чипы), не на Intel Mac.
Локальный скрипт без arm64-only настройки Flutter может собрать universal binary;
прежняя локальная сборка содержала arm64 и x86_64 и проверялась только на Apple Silicon.
Первый запуск новой CI-сборки на другом Mac ещё требует проверки.
На Windows `.app` не запускается: Windows-разработчик может передать архив владельцу Mac,
а backend запустить на Windows/WSL или на сервере. Исходный Windows runner сохранён.

## Подпись и первый запуск

В CI используется только **ad-hoc подпись**, без сертификата Apple, Developer Team,
embedded provisioning profile и notarization. Старую локальную тестовую сборку
разработчик подписывал своим **Apple Development** сертификатом.
`codesign --verify --deep --strict` проверяет целостность, но не заменяет Gatekeeper.
В обоих случаях Developer ID Application и notarization не настроены.
**Gatekeeper не принимает эту сборку как доверенный публичный дистрибутив.**
На другом Mac возможен отказ запуска. Не отключайте Gatekeeper и не снимайте
карантин массовой командой. Для обычной внешней поставки владелец Apple Developer
Program должен подписать сборку Developer ID Application, включить Hardened Runtime,
выполнить notarization и stapling, затем заново проверить архив на другом Mac.
Apple Development здесь подходит для контролируемой разработки, не является
гарантией запуска скачанного приложения на любом компьютере.
Для доверенной тестовой сборки macOS может предложить «Системные настройки →
Конфиденциальность и безопасность → Всё равно открыть». Это исключение только
для выбранного приложения, а не отключение защиты всего Mac. Ошибки повреждения
или недействительной подписи сначала расследуйте, не обходите их вслепую.

## Backend с нуля

Нужны Git, uv (он установит совместимый Python 3.14), Docker Desktop с Compose
либо Docker Engine + Compose в Linux/WSL. Redis текущему backend не требуется:
в действующем Compose определён только PostgreSQL 18. Для готового клиента эти
инструменты не нужны — только доступ к уже запущенному серверу.

Получите backend-репозиторий CRM и откройте его корень (не Flutter-репозиторий).
На macOS/Linux/WSL:

```bash
cd ~/coding/CRM
cp .env.example .env
chmod 600 .env
uv sync --locked
```

Создавайте `.env` только на новой установке: не перезаписывайте существующий файл.
Заполните его самостоятельно:

```dotenv
DB_NAME=crm
DB_USER=crm
DB_PASSWORD=REPLACE_WITH_A_RANDOM_PASSWORD
DB_HOST=127.0.0.1
DB_PORT=5432
```

Случайный пароль можно получить командой `uv run python -c 'import secrets; print(secrets.token_urlsafe(32))'`.
Замените значение-заглушку. `.env` не отправляйте другому разработчику и не коммитьте.
Пароль `DB_PASSWORD` используется PostgreSQL и **не является паролем входа в CRM**.
На существующем томе изменение `.env` не меняет пароль PostgreSQL автоматически.

```bash
docker compose up -d postgres
docker compose exec postgres pg_isready -U crm -d crm
uv run alembic upgrade head
uv run python -m cli.bootstrap_admin --login admin --full-name "Администратор CRM"
uv run uvicorn web.main:app --host 127.0.0.1 --port 8000
```

Дождитесь готовности PostgreSQL перед миграциями. Bootstrap нужен **только для пустой
установки**, отказывается при любом существующем сотруднике. Он запрашивает временный
пароль длиной 15–128 символов скрыто в терминале. При первом входе клиент предложит
сменить его. Не удаляйте сотрудников или Docker volume ради повторного bootstrap.
Для восстановления используйте документированную в backend `cli.recover_admin`.

В PowerShell установите uv и Docker Desktop, используйте `Copy-Item .env.example .env`
вместо `cp`/`chmod`; команды `uv` и `docker compose` остаются теми же. Пароль вводится
в интерактивном терминале, не через pipe или аргументы процесса.

Проверка (в другом терминале):

```bash
curl --fail http://127.0.0.1:8000/health
```

Ожидается `{"status":"ok"}`. PostgreSQL хранит данные в существующем именованном
томе Compose. Не выполняйте `docker compose down -v`, `docker volume rm` и не
меняйте major-версию PostgreSQL поверх этого тома. Не кладите backend или `.env`
внутрь `.app`. Сервер и Docker должны работать, пока клиент используется.

## Подключение готового приложения

Дважды нажмите `CRM-interface.app`. При первом запуске укажите адрес backend
и нажмите «Проверить и сохранить». Для backend на этом же Mac укажите
`http://127.0.0.1:8000` и подтвердите использование HTTP; для удалённого — HTTPS.
Адрес сохраняется. На экране входа есть ссылка «Изменить сервер».

Адрес другого backend для уже собранного приложения (без Flutter SDK):

```bash
open "/Applications/CRM-interface.app" --args --api-url=https://crm.example.org
```

Или из распакованной папки:

```bash
./Запустить\ CRM.command https://crm.example.org
```

Аргумент `--api-url=` имеет приоритет над сохранённым адресом, затем учитывается
значение, явно заданное при сборке. Без них открывается форма настройки.
Адрес должен содержать `http://` или `https://`, не должен включать логин,
пароль, query string или fragment. Допускается префикс пути, например `/api`.
Основные запросы и обновление токенов используют один и тот же адрес.
Аргумент запуска сам не сохраняется. Для постоянного подключения используйте
форму настройки; затем запускайте приложение без переопределяющего аргумента.
Смена адреса в форме очищает старую локальную сессию и требует нового входа.
Проверка соединения не пересылает токены; HTTP-перенаправления не выполняются.

`127.0.0.1` всегда означает компьютер, на котором запущен **клиент**.
Для удалённого сервера используйте HTTPS через настроенный reverse proxy либо
SSH-туннель, сохраняя backend на loopback:

```bash
ssh -N -L 8000:127.0.0.1:8000 developer@backend-host
```

Для краткой разработки в доверенной LAN backend можно запустить с
`--host 0.0.0.0`, а клиент — с `--api-url=http://SERVER_LAN_IP:8000`.
Это открывает API другим узлам; ограничьте доступ firewall. Обычный HTTP
не шифрует пароли и токены, поэтому не используйте его для рабочих данных
в удалённой сети. Порт PostgreSQL наружу не открывайте. Настройки доверенных
reverse proxy и `FORWARDED_ALLOW_IPS` описаны в backend README.

## Keychain и сессии

`flutter_secure_storage` на macOS настроен с
`MacOsOptions(usesDataProtectionKeychain: false)`: это системный macOS Keychain,
а не файл с открытым токеном. Keychain Sharing/обмен секретами с другими приложениями
не нужен; `keychain-access-groups` удалён, поэтому не нужен профиль Personal Team,
ограниченный одним Mac. App Sandbox и исходящие соединения включены и для Release.
Windows использует прежнюю реализацию secure storage.

Access-токен существует только в памяти процесса, refresh-токен — в Keychain.
Пароль пользователя не сохраняется. Выход через AuthRepository удаляет refresh-токен.
Автоматический вход после перезапуска пока не реализован: повторный экран входа
сам по себе не означает ошибку Keychain. При ошибке хранилища приложение показывает
сообщение и остаётся на форме; открытое хранение как fallback не применяется.

## Сборка из исходников на Mac

В CI закреплён Flutter 3.47.2 / Dart 3.13.2 в `.flutter-version`.
Прежняя локальная macOS-сборка проверялась на Flutter 3.47.6 / Dart 3.13.5 и Xcode 27.
Нужен Xcode с выбранными Command Line Tools и принятыми условиями Xcode.
Эти инструменты нужны только сборщику. Все команды — в корне
существующего Flutter-проекта; `flutter create` повторять не нужно.

```bash
cd ~/coding/CRM-interface
flutter pub get
flutter analyze
flutter test
flutter build macos --release
```

Результат: `build/macos/Build/Products/Release/CRM-interface.app`.
Адрес по умолчанию задаётся стандартным механизмом Dart environment declarations:

```bash
flutter build macos --release --dart-define=CRM_API_URL=https://crm.example.org
flutter run -d macos --dart-define=CRM_API_URL=http://127.0.0.1:8000
flutter run -d windows --dart-define=CRM_API_URL=http://127.0.0.1:8000
```

Для локальной подписи создайте игнорируемый Git файл
`macos/Runner/Configs/Signing.local.xcconfig`:

```xcconfig
CRM_SIGN_IDENTITY = Apple Development
CRM_DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Сертификат с приватным ключом должен уже находиться в Keychain сборщика.
Файл содержит только настройки, не экспорт ключа. Без него проект использует
ad-hoc подпись для локальной разработки. Не переносите `.p12`, `.p8`, приватные
ключи или provisioning profiles в Git/архив приложения. Bundle ID сохранён
`com.example.crmInterface`; его будущая замена потребует отдельного решения
о доступе к уже созданным Keychain-записям.

Чтобы собрать и упаковать:

```bash
./scripts/build_macos_release.sh
```

Получите `dist/CRM-macos/CRM-interface.app`, `dist/CRM-macos.zip` и
`dist/CRM-macos.zip.sha256`. ZIP создаётся через `ditto`, сохраняя структуру
macOS bundle и права выполнения. В архив не входят `.env`, тестовые пароли,
проект Xcode, исходники, приватные ключи и база данных. Скрипт не выполняет
notarization и не обещает одобрения Gatekeeper.

## Нативная проверка

`flutter test` проверяет Dart/widget-логику, но не настоящий Keychain.
Отдельный `integration_test/macos_auth_test.dart` запускается на Mac с реальным
плагином и отдельным FastAPI/PostgreSQL. Нужна **одноразовая тестовая база**,
применённые миграции и `cli.seed_demo`; нельзя направлять тест на рабочую базу:
он меняет пароль тестового администратора. Порт тестового backend — 8001.

В локальном JSON вне репозитория с правами 0600 задайте `CRM_TEST_API_URL`,
`CRM_TEST_LOGIN`, `CRM_TEST_PASSWORD`, `CRM_TEST_NEW_PASSWORD`. Пароли тестового
пользователя должны соответствовать правилам backend. Затем:

```bash
flutter test integration_test/macos_auth_test.dart -d macos --dart-define-from-file=/absolute/path/to/private-test-config.json
```

Проверяются вход, обязательная смена пароля, запись/чтение/удаление refresh-токена
через нативный Keychain, ответы клиентов/задач и переход к доске.
Тестовая сборка не предназначена для передачи. После теста повторите обычную
Release-сборку и упакуйте именно её. Удалите временный JSON и одноразовую базу.

## Источники

- [flutter_secure_storage: macOS Keychain и provisioning](https://pub.dev/packages/flutter_secure_storage#macos--ios)
- [Flutter: App Sandbox и entitlements](https://docs.flutter.dev/platform-integration/macos/building)
- [Flutter: выпуск macOS](https://docs.flutter.dev/deployment/macos)
- [Apple: подпись для распространения](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
