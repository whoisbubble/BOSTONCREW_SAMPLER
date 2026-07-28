# Гguide разработчика: Автоматический релиз через GitHub Actions 🚀

Это пошаговая инструкция по настройке автоматической сборки, упаковки и публикации релизов на GitHub для Windows и macOS при помощи файлов **GitHub Actions Workflow (`.yml`)**.

---

## 📌 Как это работает (Архитектура)

1. **Триггер тэга**: Когда вы пушите в GitHub тэг формата `v*` (например, `v1.0.1`, `v1.0.2`), GitHub Actions автоматически запускает workflow.
2. **Сборка на виртуальных машинах GitHub**:
   - На виртуальной машине `windows-2022` собираются Windows Portable `.zip` и Installer `.exe` (Inno Setup).
   - На виртуальных машинах `macos-15-intel` (x64) и `macos-15` (ARM64 Apple Silicon) собираются файлы `.dmg`.
3. **Публикация в GitHub Releases**: GitHub Actions берет описание из файла релиза (например `docs/releases/free-v1.0.1.md`) и автоматически прикрепляет собранные установочные файлы к релизу через GitHub CLI (`gh release`).

---

## ⚙️ Структура `.yml` файла

Все файлы автосборки хранятся в папке `.github/workflows/` (например `windows-deploy.yml` и `macos-deploy.yml`).

### 1. Блок триггеров (`on`)

Этот блок определяет, когда запускается автосборка:

```yaml
name: Windows Deploy

on:
  workflow_dispatch:      # Позволяет запустить сборку вручную через сайт GitHub
  push:
    branches:
      - main              # Запуск при пуше в ветку main (для обычных проверок)
    tags:
      - "v*"             # 👈 ТРИГГЕР РЕЛИЗА: Сработает только при пуше тэгов v1.0.0, v1.0.1 и т.д.
```

---

### 2. Разрешения (`permissions`)

Для того чтобы GitHub Actions мог создать релиз и загрузить в него файлы, ему нужны права на запись:

```yaml
permissions:
  contents: write
```

---

### 3. Шаги сборки (Jobs & Steps)

#### Пример шагов для Windows (`.github/workflows/windows-deploy.yml`):

```yaml
jobs:
  package-windows:
    name: Package Windows x64
    runs-on: windows-2022
    timeout-minutes: 60

    env:
      QT_VERSION: "6.10.2"
      CONFIGURATION: Release
      PORTABLE_ARCHIVE_PATH: deploy\BOSTONCREW-SAMPLER-windows-portable.zip
      INSTALLER_PATH: deploy\BOSTONCREW-SAMPLER-windows-setup.exe
      RELEASE_NOTES_PATH: docs\releases\free-v1.0.1.md

    steps:
      # 1. Скачивание исходного кода репозитория
      - name: Checkout
        uses: actions/checkout@v4

      # 2. Установка библиотеки Qt нужной версии
      - name: Install Qt
        uses: jurplel/install-qt-action@v4
        with:
          version: ${{ env.QT_VERSION }}
          host: windows
          target: desktop
          arch: win64_msvc2022_64
          modules: qtmultimedia
          cache: true

      # 3. Конфигурация через CMake
      - name: Configure
        shell: pwsh
        run: cmake -S . -B build-windows -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$env:QT_ROOT_DIR"

      # 4. Сборка бинарников
      - name: Build
        shell: pwsh
        run: cmake --build build-windows --config $env:CONFIGURATION --parallel

      # 5. Установка Inno Setup для сборки .exe установщика
      - name: Install Inno Setup
        shell: pwsh
        run: choco install innosetup --no-progress -y

      # 6. Запуск PowerShell-скрипта упаковки
      - name: Deploy portable app and installer
        shell: pwsh
        run: |
          $qtBin = Join-Path $env:QT_ROOT_DIR "bin"
          .\scripts\deploy_windows.ps1 `
            -BuildDir build-windows `
            -Configuration $env:CONFIGURATION `
            -QtBinDir $qtBin `
            -ArchivePath $env:PORTABLE_ARCHIVE_PATH `
            -InstallerPath $env:INSTALLER_PATH `
            -BuildInstaller

      # 7. Публикация файлов в GitHub Release (если сработал тэг v*)
      - name: Publish tag release assets
        if: startsWith(github.ref, 'refs/tags/')
        shell: pwsh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          for ($attempt = 1; $attempt -le 3; $attempt++) {
            gh release view "$env:GITHUB_REF_NAME" 2>$null
            if ($LASTEXITCODE -eq 0) {
              gh release upload "$env:GITHUB_REF_NAME" $env:INSTALLER_PATH $env:PORTABLE_ARCHIVE_PATH --clobber
              if ($LASTEXITCODE -eq 0) { exit 0 }
            } else {
              gh release create "$env:GITHUB_REF_NAME" $env:INSTALLER_PATH $env:PORTABLE_ARCHIVE_PATH --title "BOSTONCREW SAMPLER Free $env:GITHUB_REF_NAME" --notes-file $env:RELEASE_NOTES_PATH
              if ($LASTEXITCODE -eq 0) { exit 0 }
            }
            Start-Sleep -Seconds ($attempt * 30)
          }
          exit 1
```

---

### 4. Мульти-архитектурная матрица для macOS (`.github/workflows/macos-deploy.yml`)

Для macOS используется **матрица сборки (matrix)**, чтобы параллельно собрать дистрибутивы под Intel и Apple Silicon (M1/M2/M3):

```yaml
    strategy:
      fail-fast: false
      matrix:
        include:
          - package_arch: x64
            runner: macos-15-intel      # Ранер с процессором Intel
            cmake_arch: x86_64
          - package_arch: arm64
            runner: macos-15            # Ранер с процессором Apple Silicon
            cmake_arch: arm64
```

---

## 🛠 Пошаговая шпаргалка: Как релизить новую версию сам

Когда вы внесли все нужные фичи/исправления в код и готовы выпустить новую версию (например `v1.0.2`), выполните в консоли 4 простые команды:

### Шаг 1. Напишите заметку к релизу
Создайте файл описания релиза в `docs/releases/free-v1.0.2.md` и обновляйте путь `RELEASE_NOTES_PATH` в `.yml` файлах при необходимости.

### Шаг 2. Закоммитьте изменения
```bash
git add .
git commit -m "Release v1.0.2: Описание изменений"
```

### Шаг 3. Создайте тэг версии
```bash
git tag -a v1.0.2 -m "BOSTONCREW SAMPLER v1.0.2"
```

### Шаг 4. Отправьте код и тэг на GitHub
```bash
git push origin main
git push origin v1.0.2
```

---

## 🎯 Что произойдет дальше?

После выполнения `git push origin v1.0.2`:
1. Зайдите во вкладку **Actions** в вашем GitHub репозитории.
2. Вы увидите 2 параллельно запущенных процесса: `Windows Deploy` и `macOS Deploy`.
3. Через ~5–10 минут они завершат сборку, и в разделе **Releases** репозитория автоматически появится релиз **v1.0.2** со всеми 4 готовыми файлами для скачивания:
   - `BOSTONCREW-SAMPLER-windows-setup.exe`
   - `BOSTONCREW-SAMPLER-windows-portable.zip`
   - `BOSTONCREW-SAMPLER-macos-x64.dmg`
   - `BOSTONCREW-SAMPLER-macos-arm64.dmg`
