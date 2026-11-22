# Medieval Archery Range 3D — Стартовый проект (Godot 4 + GitHub Actions)

Рабочий вертикальный срез 3D-игры для Android (стрельба из лука от первого лица, 20 уровней, 4 средневековых биома, две сборки **Free** и **Paid** без платёжного SDK, расширяемая локализация **EN + RU**, экраны **Help** и **Settings**, готовый CI/CD на GitHub Actions).

## 1. Быстрый запуск в Godot 4
1. Распакуйте архив `medieval_archery_godot4.zip`.
2. Откройте **Godot 4.3+** → **Import** → выберите `project.godot`.
3. Нажмите **F5 (Run Project)**. Для теста платной версии в редакторе задайте `debug_force_paid = true` в `scripts/autoload/game_config.gd`.

## 2. Загрузка в ваш GitHub (3 команды)
Создайте пустой репозиторий на GitHub (без README) и выполните в распакованной папке `medieval_archery_godot4`:

```bash
git init -b main
git add .
git commit -m "Initial commit: Medieval Archery Range 3D (Godot 4)"
git remote add origin https://github.com/<ВАШ_ЛОГИН>/<ИМЯ_РЕПОЗИТОРИЯ>.git
git push -u origin main
```

После `git push` во вкладке **Actions** автоматически запустятся сборки **Debug APK** для обеих версий (`Free` и `Paid`) — готовые файлы можно скачать из **Artifacts** и сразу установить на Android-смартфон.

## 2.1. Включение веб-демки на GitHub Pages (1 клик)
В настройках репозитория откройте **Settings → Pages → Build and deployment → Source** и выберите **GitHub Actions**. После каждого `git push` в `main` игра автоматически опубликуется по адресу `https://<ВАШ_ЛОГИН>.github.io/<ИМЯ_РЕПОЗИТОРИЯ>/`.

## 3. Настройка Release AAB (подпись для Google Play)
1. Сгенерируйте release-ключ один раз локально:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias archery_release -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Закодируйте ключ в Base64 (Linux/WSL/macOS):
   ```bash
   base64 -w 0 release.keystore
   ```
3. В репозитории GitHub откройте **Settings → Secrets and variables → Actions → New repository secret** и добавьте 3 секрета:
   - `ANDROID_RELEASE_KEYSTORE_BASE64` — строка Base64 из шага 2
   - `ANDROID_RELEASE_KEYSTORE_USER` — alias ключа (например, `archery_release`)
   - `ANDROID_RELEASE_KEYSTORE_PASSWORD` — пароль ключа
4. Для сборки подписанных `.aab` поставьте тег версии (`git tag v1.0.0 && git push origin v1.0.0`) или запустите workflow вручную во вкладке **Actions** с галочкой **Build signed Release AABs**.

## 4. Добавление нового языка интерфейса
Откройте `localization/translations.csv` и добавьте новую колонку (например, `he`, `es`, `de`). Новый язык автоматически появится в **Settings**.
