# Patched phoc / Пропатченный phoc

[Русский](#русский) · [English](#english)

---

## Русский

Патчи к phoc 0.55.1 (компоновщик Phosh) для Digma CITI 1804 и похожих медленных планшетов. Сборка идёт на самом планшете, системные файлы не меняются: собранный phoc лежит в `/usr/local` и запускается через обёртку.

### Что делают патчи

| Патч | Что меняет |
|---|---|
| `no-modeset-on-rotate` | при повороте экрана нет полной перенастройки дисплея (DRM modeset), если режим не меняется. Со штатным phoc из-за неё экран чернеет на 1–1,5 с |
| `no-transform-shield` | `PHOC_NO_TRANSFORM_SHIELD=1`: при простом повороте phoc не закрывает экран чёрным, пока перестраиваются панели (на этом планшете до 3 с). Вместо черноты на долю секунды видна перестройка |
| `shield-image` | `PHOC_SHIELD_IMAGE`, `PHOC_SHIELD_DIM`: картинка (например, обои) вместо чёрного фона на экране запуска сеанса |
| `shield-logo` | `PHOC_SHIELD_LOGO_DIR`: вместо кружка на экране запуска — логотип postmarketOS из темы Plymouth `pmos-spin`, того же размера, на том же месте и с той же анимацией. `PHOC_SHIELD_FADE_MS`: плавное исчезновение экрана запуска |
| `rotate-snapshot` | `PHOC_ROTATE_SNAPSHOT=1`: поворот как в Windows. Последний кадр в старой ориентации «отъезжает» (уменьшается до 85 % и тускнеет, `PHOC_ROTATE_RECEDE_MS`), держится, пока перестраиваются панели (не дольше `PHOC_ROTATE_SNAPSHOT_MAX_MS`), и плавно сменяется новым экраном (`PHOC_ROTATE_FADE_MS`) |

Патчи накладываются по номеру (01–05). Проверено мной на планшете 25.11.2026 (postmarketOS v26.06, phoc 0.55.1): поворот со снимком, логотип вместо кружка, загрузка без падений. Найдено и исправлено по ходу: в первой версии `shield-logo` phoc падал в конце угасания (снятие покадровой анимации изнутри обработки кадра); в первой версии `rotate-snapshot` буфер снимка переиспользовался для новых кадров, и «старый» кадр показывал новую ориентацию; постоянная перерисовка во время ожидания перестройки тормозила планшет — теперь кадры рисуются только во время анимаций.

### Установка

1. Пакеты для сборки (около 150 пакетов, sudo). `libseat-dev` ставить не нужно: на systemd-версии postmarketOS он конфликтует с `systemd-dev`, `build.sh` распакует его локально сам.
   ```sh
   sudo apk add glib-dev gmobile-dev gnome-desktop-dev json-glib-dev libdrm-dev libinput-dev libxkbcommon-dev mesa-dev meson pixman-dev wayland-dev wayland-protocols systemd-dev glslang hwdata-dev libcap-dev libdisplay-info-dev libxcb-dev xcb-util-image-dev xcb-util-renderutil-dev xcb-util-wm-dev xkeyboard-config-dev xwayland-dev lcms2-dev vulkan-loader-dev vulkan-headers
   ```
2. Сборка, без sudo, около 15 минут: `sh build.sh`. Скачивает phoc с sources.phosh.mobi, проверяет контрольную сумму из пакета Alpine, накладывает патчи.
3. Установка: `sudo sh install.sh`, потом перезагрузка.

`install.sh` ставит:
- `/usr/local/lib/citi1804/phoc/phoc-<версия>` и обёртку `phoc`. Обёртка запускает пропатченный phoc только пока его версия совпадает с `/usr/bin/phoc`; после обновления ОС до другой версии сам запускается штатный. Если пропатченный phoc падает в первые 15 с, обёртка запускает штатный;
- `/usr/local/bin/phosh-session`: запуск сеанса Phosh через обёртку (экран входа находит его через `PATH`);
- настройки `/etc/citi1804/phoc.env`: правка через sudo, применяются при следующем входе;
- синхронизацию обоев: `/var/lib/citi1804/wallpaper.png` обновляется, когда обои меняются в «Настройках»; она же задана обоями по умолчанию для экрана входа phrog (показывает ли их phrog, я не подтвердил: у меня он был зелёным).

Откат: `sudo sh uninstall.sh` и перезагрузка.

После обновления phoc в системе нужно пересобрать (`build.sh`, `install.sh`), если для новой версии есть патчи. Пока их нет, работает штатный phoc.

---

## English

Patches for phoc 0.55.1 (the Phosh compositor) for the Digma CITI 1804 and similar slow tablets. They are built on the tablet itself; no system file is changed: the patched phoc lives in `/usr/local` and starts through a wrapper.

### What the patches do

| Patch | Change |
|---|---|
| `no-modeset-on-rotate` | no full display reconfiguration (DRM modeset) on rotation when the mode does not change. With the stock phoc it blacks out the screen for 1–1.5 s |
| `no-transform-shield` | `PHOC_NO_TRANSFORM_SHIELD=1`: on a plain rotation phoc does not cover the screen with black while the panels rearrange (up to 3 s on this tablet). Instead the rearranging is visible for a moment |
| `shield-image` | `PHOC_SHIELD_IMAGE`, `PHOC_SHIELD_DIM`: a picture (e.g. the wallpaper) instead of black on the session start screen |
| `shield-logo` | `PHOC_SHIELD_LOGO_DIR`: instead of the spinner, the postmarketOS logo from the Plymouth theme `pmos-spin`, same size, place and animation. `PHOC_SHIELD_FADE_MS`: fade-out of the start screen |
| `rotate-snapshot` | `PHOC_ROTATE_SNAPSHOT=1`: rotation like on Windows. The last frame, in the old orientation, recedes (shrinks to 85 % and dims, `PHOC_ROTATE_RECEDE_MS`), stays while the panels rearrange (at most `PHOC_ROTATE_SNAPSHOT_MAX_MS`) and fades into the new screen (`PHOC_ROTATE_FADE_MS`) |

The patches apply in number order (01–05). Tested by me on the tablet on 2026-11-25 (postmarketOS v26.06, phoc 0.55.1): rotation with the snapshot, logo instead of the spinner, boot without crashes. Found and fixed on the way: the first `shield-logo` crashed phoc at the end of the fade-out (a frame callback was removed from inside the frame callback loop); in the first `rotate-snapshot` the snapshot buffer was reused for new frames, so the "old" frame showed the new orientation; redrawing all the time while waiting for the panels slowed the tablet down, now frames are drawn only during the animations.

### Installation

1. Build packages (about 150, sudo). Do not install `libseat-dev`: on the systemd edition of postmarketOS it conflicts with `systemd-dev`; `build.sh` unpacks it locally by itself.
   ```sh
   sudo apk add glib-dev gmobile-dev gnome-desktop-dev json-glib-dev libdrm-dev libinput-dev libxkbcommon-dev mesa-dev meson pixman-dev wayland-dev wayland-protocols systemd-dev glslang hwdata-dev libcap-dev libdisplay-info-dev libxcb-dev xcb-util-image-dev xcb-util-renderutil-dev xcb-util-wm-dev xkeyboard-config-dev xwayland-dev lcms2-dev vulkan-loader-dev vulkan-headers
   ```
2. Build, without sudo, about 15 minutes: `sh build.sh`. Downloads phoc from sources.phosh.mobi, checks the checksum from the Alpine package, applies the patches.
3. Install: `sudo sh install.sh`, then reboot.

`install.sh` installs:
- `/usr/local/lib/citi1804/phoc/phoc-<version>` and the `phoc` wrapper. The wrapper uses the patched phoc only while its version equals `/usr/bin/phoc`; after an OS update to another version the stock one starts by itself. If the patched phoc crashes within 15 s, the wrapper starts the stock one;
- `/usr/local/bin/phosh-session`: starts the Phosh session through the wrapper (the login screen finds it via `PATH`);
- settings `/etc/citi1804/phoc.env`: edit with sudo, applied at the next login;
- wallpaper sync: `/var/lib/citi1804/wallpaper.png` follows the wallpaper chosen in Settings; it is also set as the default wallpaper of the phrog login screen (whether phrog shows it is not confirmed: on my tablet it stayed green).

Undo: `sudo sh uninstall.sh`, then reboot.

After phoc is updated in the system it must be rebuilt (`build.sh`, `install.sh`) if there are patches for the new version. Until then the stock phoc runs.
