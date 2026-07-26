# BOSTONCREW SAMPLER Free

Первый публичный бесплатный релиз BOSTONCREW SAMPLER готов к работе. Это компактный пульт для живых событий: семплы, слайды, медиа-превью, cue-звуки, таймер, сценическое окно и подключение к внешнему host через WebSocket собраны в одном desktop-приложении.

## Что внутри

- Бесплатная сборка без экрана активации в основном пользовательском потоке.
- Быстрый запуск аудио-семплов и фиксированные кнопки для player, like, dislike, timer, pause/play и stop.
- Библиотека слайдов, быстрые slide-слоты, preview, cue-выбор медиа и отдельное сценическое окно.
- Локальное remote-окно для управления активным видео на сцене.
- WebSocket-подключение к внешнему host для отправки show-команд.
- FFmpeg/FFprobe уже вложены в пакет, чтобы длительность и медиа-помощники работали сразу после установки.

## Что скачать

- `BOSTONCREW-SAMPLER-windows-setup.exe` - основной установщик для Windows.
- `BOSTONCREW-SAMPLER-windows-portable.zip` - portable-сборка для Windows.
- `BOSTONCREW-SAMPLER-macos-x64.dmg` - сборка для Mac с Intel.
- `BOSTONCREW-SAMPLER-macos-arm64.dmg` - сборка для Mac на Apple Silicon.

## Заметка для macOS

Если в репозитории не настроены Apple Developer ID secrets, macOS-пакеты собираются без подписи и notarization. В таком случае при первом запуске macOS может попросить разрешить приложение в System Settings -> Privacy & Security.

## Как собирался релиз

Артефакты собираются через GitHub Actions:

- Windows x64: Qt, CMake, windeployqt, Inno Setup, portable-архив и полноценный `.exe` installer.
- macOS Intel и Apple Silicon: отдельные DMG для каждой архитектуры с проверкой bundle metadata, Qt plugins и вложенных FFmpeg tools.

Спасибо, что пробуете бесплатную версию. Пусть управление шоу станет спокойнее, быстрее и немного приятнее.
