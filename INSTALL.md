# Установка / Installation

[Русский](#русский) · [English](#english)

---

## Русский

Пошаговая установка postmarketOS на Digma CITI 1804 для пользователя Windows. Опыт работы с Linux не нужен, но команды придётся вводить в терминале. Их можно копировать отсюда.

> ⚠️ **Шаг 6 полностью стирает Windows** и все файлы на планшете. До него всё обратимо: система работает с флешки, а Windows остаётся на месте.

### Что понадобится

- **Клавиатура-док** с тачпадом или USB-клавиатура и мышь. Тачскрин заработает только после шага 4, а до этого планшетом управляют клавиатурой и мышью.
- **USB-флешка от 8 ГБ.** Всё, что на ней лежит, будет стёрто.
- **Зарядное устройство.** Держите планшет на зарядке во время установки.
- **Wi-Fi** с выходом в интернет.
- **Компьютер с Windows** для записи флешки. Можно использовать сам планшет, пока на нём Windows.

### Шаг 0. Сохраните данные

1. Скопируйте с планшета всё нужное. После шага 6 восстановить файлы будет невозможно.
2. Если планируете когда-нибудь вернуть Windows, заранее сделайте флешку восстановления Windows с драйверами планшета.

### Шаг 1. Скачайте образ

1. Откройте каталог образов: <https://images.nura.eco/bpo/v26.06/generic-x86_64/phosh/>. Проект postmarketOS переименован в Nura, а старый адрес `images.postmarketos.org` перенаправляет туда же.
2. Зайдите в папку с самой свежей датой и скачайте файл, имя которого кончается на **`-lts.img.xz`**. Проверенная версия — `20261106-0131-nura-v26.06-phosh-generic-x86_64-lts.img.xz`.
3. По желанию проверьте файл. Рядом лежит `.sha256`, а в PowerShell проверка делается командой `Get-FileHash <файл>.img.xz`: вывод должен совпасть с содержимым `.sha256`.

### Шаг 2. Запишите образ на флешку

1. Установите [balenaEtcher](https://etcher.balena.io/) — им записывали флешку для этого проекта. Он принимает `.img.xz` без распаковки.
2. В программе выберите образ, затем флешку и нажмите «Flash».
3. Если после записи Windows предложит отформатировать флешку, нажмите «Отмена». Это нормально: Windows не понимает разделы Linux.

### Шаг 3. Загрузитесь с флешки

1. Вставьте флешку в USB-порт дока и выключите планшет.
2. Включите планшет и сразу нажимайте **`Delete`** — на клавиатуре дока это **`Fn` + `Backspace`**. Откроется настройка BIOS.
3. В BIOS откройте вкладку **«Save & Exit»** и в списке **«Boot Override»** выберите флешку. Нужен пункт с «UEFI» в названии.
4. Появится меню загрузчика, затем экран входа Phosh. Пароль пользователя по умолчанию — **`147147`**. Это общий пароль образа, его вы смените в шаге 4.
5. Подключитесь к Wi-Fi через верхнюю панель.
6. Откройте приложение **«Консоль»** (Console или King's Cross). В нём вы будете вводить все дальнейшие команды. Команды с `sudo` запросят ваш пароль.

### Шаг 4 (быстрый путь). Всё одной командой

Шаги 4, 5 и 5а можно выполнить одним скриптом. Он обновляет систему, применяет все настройки железа и собирает модули Bluetooth и глубокого сна под установленное ядро (при другой версии ядра сам скачивает нужные исходники с kernel.org). После этого он **по очереди спрашивает** про дополнительные приложения (шаг 7): LibreOffice, утилиты, Pipeline, настройки Firefox, Telegram, Spotify, Steam. По умолчанию (Enter) — «нет»:

```sh
passwd
sudo apk add git
git clone https://github.com/darkonline/cherry-trail-linux_digma-citi-1804.git ~/digma-citi1804-linux
sh ~/digma-citi1804-linux/setup/restore.sh
sudo reboot
```

Запускайте от обычного пользователя, без `sudo`: пароль скрипт спросит сам. `--no-apps` — только железо, без вопросов про приложения; `--all-apps` — поставить все приложения без вопросов; `--check` — показать, что будет сделано, ничего не меняя. Повторный запуск безопасен. Дальше переходите к шагу 6.

Если хотите делать всё вручную или понять, что делает скрипт, — шаги ниже.

### Шаг 4. Обновите систему и примените настройки планшета

```sh
passwd                                  # задайте свой пароль вместо 147147
sudo apk update && sudo apk upgrade     # обновление системы и ядра; запускайте здесь, а не по SSH
sudo apk add git
git clone https://github.com/darkonline/cherry-trail-linux_digma-citi-1804.git ~/digma-citi1804-linux
cd digma-citi1804-linux
```

Если Wi-Fi обрывается на больших загрузках, просто повторите `sudo apk upgrade`.

**Системные настройки** (тач, звук, яркость, курсор, масштаб):

```sh
sudo install -D -m644 firmware/silead/mssl1680.fw /lib/firmware/silead/mssl1680.fw
sudo install -D -m644 -t /etc/kernel-cmdline.d config/etc/kernel-cmdline.d/*.conf
sudo install -D -m644 -t /etc/mkinitfs/modules config/etc/mkinitfs/modules/00-citi1804.modules
sudo install -D -m644 config/etc/phosh/phoc.ini /etc/phosh/phoc.ini
grep -q WLR_NO_HARDWARE_CURSORS /etc/environment || echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment
sudo mkinitfs
```

**Настройки пользователя** (звук без заиканий, автопереключение динамик/наушники, кнопка питания):

```sh
install -D -m644 config/home/.config/pulse/default.pa ~/.config/pulse/default.pa
install -D -m755 config/home/.local/bin/jack-profile-switch.sh ~/.local/bin/jack-profile-switch.sh
install -D -m644 config/home/.config/systemd/user/jack-profile-switch.service ~/.config/systemd/user/jack-profile-switch.service
systemctl --user daemon-reload && systemctl --user enable jack-profile-switch
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
```

Последняя команда убирает необходимость дважды нажимать кнопку питания после сна.

**Освобождение памяти**, по желанию. Скрипты удаляют приложения для звонков и SMS (модема в планшете нет) и отключают ненужные фоновые службы:

```sh
sudo sh tools/bg-system.sh
sh tools/bg-user.sh
```

Перезагрузите планшет: `sudo reboot`. После перезагрузки должны работать тачскрин, яркость, звук из динамика и автопереключение на наушники.

### Шаг 5. Bluetooth

В ядре postmarketOS выключена поддержка Bluetooth этого планшета, поэтому модуль собирается вручную:

```sh
uname -r                                # версия ядра
sudo apk add linux-lts-dev build-base
cd ~/digma-citi1804-linux/bluetooth
cp src/* .
sh build-bt.sh
sudo install -D -m644 hci_uart.ko /lib/modules/$(uname -r)/updates/hci_uart.ko
sudo depmod $(uname -r)
sudo reboot
```

- Исходники в `src/` взяты из ядра **6.18.63**. Если `uname -r` показывает другую версию, скачайте с <https://kernel.org> архив ядра этой версии и замените файлы из `src/` файлами из папки `drivers/bluetooth/` архива.
- ⚠️ **После каждого обновления ядра модуль нужно собирать заново.** Без этого Bluetooth пропадёт, а остальная система будет работать.

### Шаг 5а. Глубокий сон (экономия батареи во сне)

Без этого шага процессор во сне не уходит в состояние S0i3: неиспользуемый процессор камер (ISP) остаётся включённым, и батарея садится примерно на 3 % в час. Модуль выключает ISP:

```sh
cd ~/digma-citi1804-linux/power-isp
sh build.sh
sudo install -D -m644 intel_atomisp2_pm.ko /lib/modules/$(uname -r)/updates/intel_atomisp2_pm.ko
sudo depmod $(uname -r)
sudo reboot
```

Проверка после сна: `sudo cat /sys/kernel/debug/pmc_atom/sleep_state` — значение `S0I3 Residency` должно расти. Как и Bluetooth, модуль пересобирается после каждого обновления ядра.

### Шаг 6. Установка на внутреннюю память — стирает Windows

Проверьте, что с флешки всё работает. Затем, всё ещё загрузившись с флешки:

```sh
sudo apk add rsync efibootmgr parted dosfstools e2fsprogs
sudo sh ~/digma-citi1804-linux/install/install-emmc.sh
```

- Скрипт показывает разделы внутренней памяти и ждёт, пока вы введёте `YES`.
- Он переносит на внутреннюю память всю систему вместе с настройками и делает её загрузочной.
- В конце выключите планшет, выньте флешку и включите снова.
- Флешка не изменяется. Сохраните её как систему для восстановления.

> Скрипт сам находит встроенную память: это единственное устройство eMMC, на котором не запущена система. Карты microSD и флешки он не трогает. Если подходящих устройств несколько, скрипт остановится и покажет список. Сначала можно проверить, что он выбрал, ничего не меняя:
> ```sh
> sudo sh ~/digma-citi1804-linux/install/install-emmc.sh --check
> ```

### Шаг 7. Приложения, по желанию

- **YouTube без браузера** — приложение Pipeline с аппаратным видео:
  ```sh
  sudo apk add pipeline mpv yt-dlp clapper libpeas2-python3
  sudo ln -s /usr/lib/gstreamer-1.0/libgstclapper.so /usr/lib/libgstclapper.so
  install -D -m644 ~/digma-citi1804-linux/config/home/.local/share/applications/de.schmidhuberj.tubefeeder.desktop ~/.local/share/applications/de.schmidhuberj.tubefeeder.desktop
  ```
- **Видео в Firefox**: скопируйте `config/home/firefox/user.js` в папку профиля `~/.mozilla/firefox/<что-то>.default-release/` и перезапустите Firefox.
- **Telegram, Spotify, Steam** — ставятся через Flathub в «Центре приложений». Пакет Telegram из репозитория сломан, берите Flatpak. Spotify без звука исправляется так:
  ```sh
  flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client
  ```

### Если что-то пошло не так

| Проблема | Что делать |
|---|---|
| Тач не работает | Проверьте, есть ли файл `/lib/firmware/silead/mssl1680.fw` и выполнена ли `sudo mkinitfs`. |
| Нет регулировки яркости | Должен быть файл `/etc/mkinitfs/modules/00-citi1804.modules`, затем `sudo mkinitfs`. |
| Звук тихий и «булькает» | Проверьте, есть ли `/etc/kernel-cmdline.d/91-citi1804-audio.conf`, затем `sudo mkinitfs`. |
| Пропал Bluetooth или батарея снова быстро садится во сне | Обновилось ядро — повторите шаги 5 и 5а. |
| Не загружается после обновления | Загрузитесь с флешки-восстановления. Никогда не кладите в корень `/boot` лишних файлов `vmlinuz*`. |
| Экран на миг гаснет при повороте | Известная проблема, см. README. |

---

## English

Step-by-step installation of postmarketOS on the Digma CITI 1804 for a Windows user. No Linux experience is needed, but you will type commands into a terminal; you can copy them from here.

> ⚠️ **Step 6 erases Windows** and every file on the tablet. Everything before it is reversible: the system runs from a USB drive and Windows stays in place.

### You will need

- **The keyboard dock** with touchpad, or a USB keyboard and mouse. The touchscreen only starts working after step 4.
- **A USB flash drive of 8 GB or more.** Everything on it will be erased.
- **A charger.** Keep the tablet plugged in during installation.
- **Wi-Fi** with Internet access.
- **A Windows PC** to write the drive. The tablet itself works too, while it still runs Windows.

### Step 0. Back up your data

1. Copy everything you need off the tablet. After step 6 it cannot be recovered.
2. If you might want Windows back one day, make a Windows recovery drive with the tablet's drivers first.

### Step 1. Download the image

1. Open the image index: <https://images.nura.eco/bpo/v26.06/generic-x86_64/phosh/>. postmarketOS has been renamed to Nura, and the old `images.postmarketos.org` address redirects there.
2. Open the folder with the newest date and download the file ending in **`-lts.img.xz`**. Tested: `20261106-0131-nura-v26.06-phosh-generic-x86_64-lts.img.xz`.
3. Optionally, verify it: `Get-FileHash <file>.img.xz` in PowerShell must match the `.sha256` file next to it.

### Step 2. Write the image to the USB drive

1. Install [balenaEtcher](https://etcher.balena.io/), the tool used for this project. It accepts `.img.xz` directly.
2. Select the image, then the drive, then click "Flash".
3. If Windows then offers to format the drive, click "Cancel". That's normal: Windows can't read Linux partitions.

### Step 3. Boot from the USB drive

1. Plug the drive into the dock's USB port and turn the tablet off.
2. Power on and immediately keep pressing **`Delete`**, which is **`Fn` + `Backspace`** on the dock keyboard. BIOS setup opens.
3. Go to the **"Save & Exit"** tab and pick the USB drive under **"Boot Override"**; choose the entry with "UEFI" in its name.
4. After the boot menu, the Phosh login screen appears. The default password is **`147147`**. It's shared by every copy of the image, so you'll change it in step 4.
5. Connect to Wi-Fi from the top panel.
6. Open the **Console** (or King's Cross) app. You'll type all further commands there. Commands with `sudo` ask for your password.

### Step 4 (quick path). Everything with one command

Steps 4, 5 and 5a can be done by one script. It updates the system, applies all hardware settings and builds the Bluetooth and deep-sleep modules for the installed kernel (for another kernel version it downloads the matching sources from kernel.org). Then it **asks one by one** about optional apps (step 7): LibreOffice, utilities, Pipeline, Firefox settings, Telegram, Spotify, Steam. The default (Enter) is "no":

```sh
passwd
sudo apk add git
git clone https://github.com/darkonline/cherry-trail-linux_digma-citi-1804.git ~/digma-citi1804-linux
sh ~/digma-citi1804-linux/setup/restore.sh
sudo reboot
```

Run it as the normal user, without `sudo`; it asks for your password when needed. `--no-apps` does the hardware setup without asking about apps; `--all-apps` installs every app without asking; `--check` prints what would be done and changes nothing. Running it again is safe. Then go to step 6.

The manual steps below show what the script does.

### Step 4. Update and apply the tablet configuration

```sh
passwd                                  # set your own password instead of 147147
sudo apk update && sudo apk upgrade     # system and kernel update; run it here, not over SSH
sudo apk add git
git clone https://github.com/darkonline/cherry-trail-linux_digma-citi-1804.git ~/digma-citi1804-linux
cd digma-citi1804-linux
```

If Wi-Fi drops during a large download, just rerun `sudo apk upgrade`.

**System settings** (touch, audio, backlight, cursor, scale):

```sh
sudo install -D -m644 firmware/silead/mssl1680.fw /lib/firmware/silead/mssl1680.fw
sudo install -D -m644 -t /etc/kernel-cmdline.d config/etc/kernel-cmdline.d/*.conf
sudo install -D -m644 -t /etc/mkinitfs/modules config/etc/mkinitfs/modules/00-citi1804.modules
sudo install -D -m644 config/etc/phosh/phoc.ini /etc/phosh/phoc.ini
grep -q WLR_NO_HARDWARE_CURSORS /etc/environment || echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment
sudo mkinitfs
```

**User settings** (stutter-free audio, speaker/headphone switching, power button):

```sh
install -D -m644 config/home/.config/pulse/default.pa ~/.config/pulse/default.pa
install -D -m755 config/home/.local/bin/jack-profile-switch.sh ~/.local/bin/jack-profile-switch.sh
install -D -m644 config/home/.config/systemd/user/jack-profile-switch.service ~/.config/systemd/user/jack-profile-switch.service
systemctl --user daemon-reload && systemctl --user enable jack-profile-switch
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
```

The last command fixes having to press the power button twice after suspend.

**Freeing memory** (optional). These remove the phone apps (the tablet has no modem) and disable background services you don't need:

```sh
sudo sh tools/bg-system.sh
sh tools/bg-user.sh
```

Reboot with `sudo reboot`. Touch, backlight, speaker audio and headphone switching should now work.

### Step 5. Bluetooth

The kernel has this tablet's Bluetooth support disabled, so the module is built locally:

```sh
uname -r                                # kernel version
sudo apk add linux-lts-dev build-base
cd ~/digma-citi1804-linux/bluetooth
cp src/* .
sh build-bt.sh
sudo install -D -m644 hci_uart.ko /lib/modules/$(uname -r)/updates/hci_uart.ko
sudo depmod $(uname -r)
sudo reboot
```

- The sources in `src/` come from kernel **6.18.63**. If `uname -r` shows another version, download that kernel version from <https://kernel.org> and replace the `src/` files with the ones from its `drivers/bluetooth/` folder.
- ⚠️ **Rebuild the module after every kernel update.** Otherwise Bluetooth disappears; the rest of the system keeps working.

### Step 5a. Deep sleep (battery life in suspend)

Without this step the SoC never reaches S0i3 in suspend: the unused camera ISP stays powered and the battery drains about 3 % per hour. This module powers the ISP off:

```sh
cd ~/digma-citi1804-linux/power-isp
sh build.sh
sudo install -D -m644 intel_atomisp2_pm.ko /lib/modules/$(uname -r)/updates/intel_atomisp2_pm.ko
sudo depmod $(uname -r)
sudo reboot
```

Check after a suspend: `sudo cat /sys/kernel/debug/pmc_atom/sleep_state`; `S0I3 Residency` should grow. Like Bluetooth, rebuild it after every kernel update.

### Step 6. Install to internal storage (erases Windows)

Make sure everything works from the USB drive. Then, still booted from it:

```sh
sudo apk add rsync efibootmgr parted dosfstools e2fsprogs
sudo sh ~/digma-citi1804-linux/install/install-emmc.sh
```

- The script shows the internal storage partitions and waits for you to type `YES`.
- It copies the whole system with your settings to internal storage and makes it bootable.
- At the end, power off, remove the USB drive and power on.
- The USB drive isn't modified. Keep it as a rescue system.

> The script finds the internal storage by itself: the only eMMC device that isn't running the system. It never touches microSD cards or USB drives. If several devices qualify, it stops and lists them. To see what it would pick without changing anything:
> ```sh
> sudo sh ~/digma-citi1804-linux/install/install-emmc.sh --check
> ```

### Step 7. Apps (optional)

- **YouTube without a browser**: Pipeline with hardware video decoding:
  ```sh
  sudo apk add pipeline mpv yt-dlp clapper libpeas2-python3
  sudo ln -s /usr/lib/gstreamer-1.0/libgstclapper.so /usr/lib/libgstclapper.so
  install -D -m644 ~/digma-citi1804-linux/config/home/.local/share/applications/de.schmidhuberj.tubefeeder.desktop ~/.local/share/applications/de.schmidhuberj.tubefeeder.desktop
  ```
- **Video in Firefox**: copy `config/home/firefox/user.js` into `~/.mozilla/firefox/<something>.default-release/` and restart Firefox.
- **Telegram, Spotify, Steam**: install them from Flathub in the Software app. The Telegram package in the repository is broken, so use the Flatpak. If Spotify plays without sound:
  ```sh
  flatpak override --user --nofilesystem=xdg-run/pipewire-0 com.spotify.Client
  ```

### Troubleshooting

| Problem | Fix |
|---|---|
| Touch doesn't work | Check that `/lib/firmware/silead/mssl1680.fw` exists and that `sudo mkinitfs` was run. |
| No backlight control | `/etc/mkinitfs/modules/00-citi1804.modules` must exist, then run `sudo mkinitfs`. |
| Speaker is quiet and "bubbly" | Check `/etc/kernel-cmdline.d/91-citi1804-audio.conf`, then run `sudo mkinitfs`. |
| Bluetooth gone, or fast battery drain in suspend again | The kernel was updated: repeat steps 5 and 5a. |
| Doesn't boot after an update | Boot from the rescue USB drive. Never leave extra `vmlinuz*` files in the root of `/boot`. |
| Screen blanks briefly on rotation | Known issue, see README. |
