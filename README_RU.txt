Сборка Samba WebUI с WS-Discovery для ARMv7 и ARM64

Этот набор собирает настоящий Android/Bionic бинарник wsdd2 для двух ABI и затем встраивает их в исходный Magisk/KernelSU модуль. Готовый ZIP не включён, потому что бинарники должны быть скомпилированы в CI с Android NDK.

Как использовать:
1. Распакуйте этот архив в новый GitHub-репозиторий.
2. Убедитесь, что base-module.zip находится в корне, рядом с build.sh.
3. Загрузите файлы и папку .github в ветку main.
4. Откройте Actions -> Build Samba WebUI with WS-Discovery (ARMv7 + ARM64) -> Run workflow.
5. Скачайте Artifact SambaWebUI-ARMv7-ARM64-WS-Discovery. Внутри будет установочный ZIP.
6. Сначала сохраните резервную копию текущего модуля и данных /data/adb/samba-webui.

Скрипт не перезаписывает shares.tsv, settings.conf или smbpasswd в persistent state. Он добавляет wsdd2-armv7/wsdd2-arm64 и запускает подходящий бинарник при запуске модуля; stop.sh завершает процесс.

WS-Discovery использует UDP multicast 239.255.255.250:3702; маршрутизатор/AP должен пропускать multicast между клиентами. Сам по себе WSD не меняет доступ по SMB-порту 445.

Исходный wsdd2: https://github.com/fenglichaoHD/wsdd2 (GPL-3.0). Сборка и фактический запуск на конкретной прошивке должны быть проверены после установки.
