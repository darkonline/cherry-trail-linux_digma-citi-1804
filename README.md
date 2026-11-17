# Linux (postmarketOS) on Digma CITI 1804 (Cherry Trail)

[Русский](#русский) · [English](#english)

**Пошаговая установка для пользователя Windows / Step-by-step installation for Windows users: [INSTALL.md](INSTALL.md)**

---

## Русский

Настройки, скрипты и прошивка для запуска postmarketOS (оболочка Phosh) на планшете **Digma CITI 1804**.
Проверено на postmarketOS v26.06, ядро `linux-lts` 6.18.63.

### Железо

| | |
|---|---|
| Процессор | Intel Atom x5-Z8350 (Cherry Trail), 2 ГБ ОЗУ, eMMC Biwin 32 ГБ |
| UEFI | 32-битный (нужен `systemd-bootia32.efi`) |
| Экран | DSI-1, 1200×1920 (родная ориентация — портретная) |
| Тачскрин | Silead MSSL1680 (I²C) |
| Звук | RT5651 + Intel SST/SOF, динамик — моно-усилитель между LOUT L и R |
| Wi-Fi / Bluetooth | Realtek RTL8723BS (SDIO / UART H5) |
| Питание | AXP288 (зарядка и счётчик заряда работают) |

### Что работает

| Что | Состояние | Как |
|---|---|---|
| Загрузка с eMMC и с флешки | ✅ | `install/install-emmc.sh` (сам находит eMMC) |
| Тачскрин | ✅ | параметры ядра + прошивка `firmware/silead/mssl1680.fw` |
| Яркость | ✅ | модуль `pwm-lpss-platform` в initramfs |
| Зарядка, батарея | ✅ | модуль `axp20x-i2c` в initramfs |
| Звук: динамик, наушники, автопереключение | ✅ | quirk ядра + `jack-profile-switch` |
| Встроенный микрофон | ✅ | |
| Wi-Fi | ✅ | |
| Bluetooth | ✅ | пересобранный `hci_uart` (H5 + RTL), `bluetooth/` |
| Автоповорот | ✅ | экран на миг чернеет при каждом повороте, см. «Известные проблемы» |
| Аппаратное видео (VA-API) | ✅ | драйвер i965, `config/home/...` |
| Сон (s2idle) с глубоким S0i3 | ✅ | модуль `intel_atomisp2_pm`, `power-isp/` |
| Камеры | ⛔ выключены | у меня камеры неисправны аппаратно (не работают и в заводской Windows); драйверы и инструкция включения — [camera/](camera/README.md). Включение камер отключает глубокий сон |
| Звук по HDMI | ❓ не проверено | нет кабеля micro-HDMI |
| Микрофон гарнитуры (3,5 мм) | ❓ не проверено | нужна гарнитура с микрофоном (штекер с 4 контактами, TRRS); наушники в разъёме работают |

### Установка настроек

**Полная пошаговая инструкция для пользователя Windows — [INSTALL.md](INSTALL.md).** Ниже — краткая справка для тех, кто уже знаком с Linux.

Пути в `config/` повторяют пути в системе: `config/etc/...` → `/etc/...`, `config/home/...` → `~/...`.

1. **Тачскрин.** Скопируйте `firmware/silead/mssl1680.fw` в `/lib/firmware/silead/mssl1680.fw` и `config/etc/kernel-cmdline.d/90-citi1804-touch.conf` в `/etc/kernel-cmdline.d/`:
   ```
   i2c_touchscreen_props=MSSL1680:touchscreen-size-x=1728:touchscreen-size-y=1152:touchscreen-swapped-x-y:silead,home-button
   ```
2. **Звук динамика и разъёма.** `91-citi1804-audio.conf`:
   ```
   snd_soc_sst_bytcr_rt5651.quirk=25310226
   ```
   Это `0x1823412`: стандартные `0x23412` + `BYT_RT5651_MONO_SPEAKER` (бит 23) + `BYT_RT5651_JD_NOT_INV` (бит 24).
3. **Модули initramfs.** `config/etc/mkinitfs/modules/00-citi1804.modules` → `/etc/mkinitfs/modules/`.
4. После шагов 1–3 выполните `sudo mkinitfs` и перезагрузитесь.
5. **Курсор.** `WLR_NO_HARDWARE_CURSORS=1` в `/etc/environment`.
6. **Масштаб 150 %.** Секция `[output:DSI-1]` / `scale = 1.5` в `/etc/phosh/phoc.ini`.
7. **Звук: PulseAudio.** `~/.config/pulse/default.pa` с `module-udev-detect tsched=0` (убирает заикания).
8. **Автопереключение динамик ↔ наушники.** `jack-profile-switch.sh` → `~/.local/bin/`, `.service` → `~/.config/systemd/user/`, затем `systemctl --user enable --now jack-profile-switch`.
9. **Bluetooth.** См. `bluetooth/build-bt.sh`. Модуль нужно пересобирать после **каждого** обновления ядра.

### Известные проблемы

- **Чёрная вспышка при повороте экрана.** Phosh при повороте отправляет всю конфигурацию экрана, а phoc при этом вызывает `wlr_output_state_set_enabled` и `wlr_output_state_set_mode`. В wlroots 0.20 оба вызова выставляют `allow_reconfiguration`, и выполняется полная перенастройка дисплея (DRM modeset). Сам поворот её не требует. Исправление — патч phoc; пока не сделано и не проверено.
- **Spotify (Flatpak) играет без звука**: `flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client`. Здесь звуком владеет PulseAudio, а у PipeWire нет выходов.
- **Pipeline (YouTube) падает в libEGL**: запуск с `GSK_RENDERER=gl`, см. `.desktop` в `config/home/.local/share/applications/`.
- **Двойное нажатие кнопки питания после сна**: Phosh получает нажатие, разбудившее планшет, и сразу гасит экран.
- **Имена eMMC (`mmcblk0`/`mmcblk1`) меняются между загрузками** — используйте `/dev/disk/by-id/`.

### Состав

| Папка | Что внутри |
|---|---|
| `config/` | готовые файлы настроек |
| `firmware/silead/` | прошивка тачскрина, извлечённая из Windows-драйвера Silead |
| `bluetooth/` | сборка `hci_uart.ko` вне дерева ядра (H5 + Realtek) |
| `power-isp/` | сборка `intel_atomisp2_pm.ko`: выключает ISP камер, чтобы работал глубокий сон |
| `camera/` | драйверы камер (atomisp, ov2680, gc0310), включение и выключение; по умолчанию выключены |
| `setup/` | `restore.sh` — вся настройка одной командой; `save-state.sh` — снимок настроек планшета |
| `install/` | установка на eMMC |
| `tools/` | замер батареи, масштаб, разгрузка фоновых служб, тесты звука |
| `diagnostics/scripts/` | скрипты диагностики, в т.ч. разбор сырых данных тача |
| `docs/` | журнал замера перенастроек экрана при повороте |

### Драйверы Windows

Если понадобится вернуть Windows:

- Официальные (сервер Digma / ddixlab):
  - [1804_driver_factory.zip](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/1804_driver_factory.zip)
  - [citi_1804_cs1069Eew_rev1_drivers_20171229.rar](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/citi_1804_cs1069Eew_rev1_drivers_20171229.rar)
  - [citi_1804_cs1069ew_rev1_Win10x32_drivers_RS3_20180426.rar](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/citi_1804_cs1069ew_rev1_Win10x32_drivers_RS3_20180426.rar)
- Неофициальная резервная копия: [Яндекс Диск](https://disk.yandex.com/d/gQq07SXp3T3nWG)

### Лицензии

- Скрипты и настройки — MIT (`LICENSE`).
- `bluetooth/src/`, `power-isp/pm.c`, `camera/src/`, `camera/test/` — код ядра Linux и модули под GPL-2.0.
- `firmware/silead/mssl1680.fw` — прошивка Silead из Windows-драйвера. Права принадлежат производителю, лицензия на распространение неизвестна.

---

## English

Configuration, scripts and firmware for running postmarketOS (Phosh shell) on the **Digma CITI 1804** tablet.
Tested on postmarketOS v26.06, kernel `linux-lts` 6.18.63.

### Hardware

| | |
|---|---|
| CPU | Intel Atom x5-Z8350 (Cherry Trail), 2 GB RAM, 32 GB Biwin eMMC |
| UEFI | 32-bit (needs `systemd-bootia32.efi`) |
| Display | DSI-1, 1200×1920 (native orientation is portrait) |
| Touchscreen | Silead MSSL1680 (I²C) |
| Audio | RT5651 + Intel SST/SOF; the speaker is a mono amp between LOUT L and R |
| Wi-Fi / Bluetooth | Realtek RTL8723BS (SDIO / UART H5) |
| Power | AXP288 (charger and fuel gauge work) |

### Status

| Feature | Status | How |
|---|---|---|
| Boot from eMMC and USB | ✅ | `install/install-emmc.sh` |
| Touchscreen | ✅ | kernel parameters + `firmware/silead/mssl1680.fw` |
| Backlight | ✅ | `pwm-lpss-platform` in initramfs |
| Charging, battery | ✅ | `axp20x-i2c` in initramfs |
| Audio: speaker, headphones, auto-switching | ✅ | kernel quirk + `jack-profile-switch` |
| Internal microphone | ✅ | |
| Wi-Fi | ✅ | |
| Bluetooth | ✅ | rebuilt `hci_uart` (H5 + RTL), `bluetooth/` |
| Auto-rotation | ✅ | the screen blanks briefly on each rotation, see Known issues |
| Hardware video decoding (VA-API) | ✅ | i965 driver, `config/home/...` |
| Suspend (s2idle) with deep S0i3 | ✅ | `intel_atomisp2_pm` module, `power-isp/` |
| Cameras | ⛔ disabled | hardware fault on my tablet (they don't work in the factory Windows either); drivers and how to enable them: [camera/](camera/README.md). Enabling the cameras disables deep sleep |
| HDMI audio | ❓ untested | no micro-HDMI cable |
| Headset microphone (3.5 mm) | ❓ untested | needs a headset with a microphone (4-contact TRRS plug); headphones in the jack work |

### Applying the configuration

**Full step-by-step guide for Windows users: [INSTALL.md](INSTALL.md#english).** Below is a short reference for people who already know Linux.

Paths under `config/` mirror the system: `config/etc/...` → `/etc/...`, `config/home/...` → `~/...`.

1. **Touchscreen.** Copy `firmware/silead/mssl1680.fw` to `/lib/firmware/silead/mssl1680.fw` and `config/etc/kernel-cmdline.d/90-citi1804-touch.conf` to `/etc/kernel-cmdline.d/`:
   ```
   i2c_touchscreen_props=MSSL1680:touchscreen-size-x=1728:touchscreen-size-y=1152:touchscreen-swapped-x-y:silead,home-button
   ```
2. **Speaker and jack.** `91-citi1804-audio.conf`:
   ```
   snd_soc_sst_bytcr_rt5651.quirk=25310226
   ```
   That is `0x1823412`: the default `0x23412` + `BYT_RT5651_MONO_SPEAKER` (bit 23) + `BYT_RT5651_JD_NOT_INV` (bit 24).
3. **initramfs modules.** `config/etc/mkinitfs/modules/00-citi1804.modules` → `/etc/mkinitfs/modules/`.
4. After steps 1–3, run `sudo mkinitfs` and reboot.
5. **Cursor.** `WLR_NO_HARDWARE_CURSORS=1` in `/etc/environment`.
6. **150 % scale.** Add `[output:DSI-1]` / `scale = 1.5` to `/etc/phosh/phoc.ini`.
7. **PulseAudio.** `~/.config/pulse/default.pa` with `module-udev-detect tsched=0` (fixes stutter).
8. **Speaker ↔ headphones switching.** `jack-profile-switch.sh` → `~/.local/bin/`, `.service` → `~/.config/systemd/user/`, then `systemctl --user enable --now jack-profile-switch`.
9. **Bluetooth.** See `bluetooth/build-bt.sh`. The module must be rebuilt after **every** kernel update.

### Known issues

- **Black flash on screen rotation.** On rotation, Phosh sends the whole output configuration, and phoc calls `wlr_output_state_set_enabled` and `wlr_output_state_set_mode`. In wlroots 0.20 both set `allow_reconfiguration`, which forces a full DRM modeset. The rotation itself doesn't need one. Fix: patch phoc. Not done or tested yet.
- **Spotify (Flatpak) is silent**: `flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client`. PulseAudio owns the audio devices here, and PipeWire has no sinks.
- **Pipeline (YouTube) crashes in libEGL**: launch it with `GSK_RENDERER=gl`, see the `.desktop` file in `config/home/.local/share/applications/`.
- **Power button needs a double press after suspend**: Phosh receives the wake-up press and blanks the screen again.
- **eMMC names (`mmcblk0`/`mmcblk1`) change between boots**; use `/dev/disk/by-id/`.

### Contents

| Folder | Contents |
|---|---|
| `config/` | ready-to-use configuration files |
| `firmware/silead/` | touchscreen firmware extracted from the Silead Windows driver |
| `bluetooth/` | out-of-tree build of `hci_uart.ko` (H5 + Realtek) |
| `power-isp/` | build of `intel_atomisp2_pm.ko`: powers off the camera ISP so deep sleep works |
| `camera/` | camera drivers (atomisp, ov2680, gc0310), enable and disable; disabled by default |
| `setup/` | `restore.sh`: the whole setup in one command; `save-state.sh`: snapshot of the tablet settings |
| `install/` | eMMC installation |
| `tools/` | battery logger, scaling, background-service cleanup, audio tests |
| `diagnostics/scripts/` | diagnostic scripts, including a raw touch data parser |
| `docs/` | log of display modesets measured during rotation |

### Windows drivers

If you ever want Windows back:

- Official (Digma / ddixlab server):
  - [1804_driver_factory.zip](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/1804_driver_factory.zip)
  - [citi_1804_cs1069Eew_rev1_drivers_20171229.rar](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/citi_1804_cs1069Eew_rev1_drivers_20171229.rar)
  - [citi_1804_cs1069ew_rev1_Win10x32_drivers_RS3_20180426.rar](https://www.ddixlab.com/public/digma/tabletpc/citi/citi_1804_cs1069ew/citi_1804_cs1069ew_rev1_Win10x32_drivers_RS3_20180426.rar)
- Unofficial backup: [Yandex Disk](https://disk.yandex.com/d/gQq07SXp3T3nWG)

### Licenses

- Scripts and configuration: MIT (`LICENSE`).
- `bluetooth/src/`, `power-isp/pm.c`, `camera/src/`, `camera/test/`: Linux kernel code and modules, GPL-2.0.
- `firmware/silead/mssl1680.fw`: Silead firmware from the Windows driver. Copyright belongs to the vendor; the redistribution license is unknown.
