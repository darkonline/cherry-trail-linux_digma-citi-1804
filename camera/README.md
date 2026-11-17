# Камеры / Cameras

[Русский](#русский) · [English](#english)

---

## Русский

### Состояние

**По умолчанию камеры выключены.** У меня камеры планшета неисправны аппаратно. Проверено тремя способами:

| Система | Результат |
|---|---|
| Linux 6.18, драйверы ниже | обе камеры не отвечают по I²C (`-121`) при включённых питании и тактовом сигнале, при любой полярности GPIO |
| Windows 10 1709, заводские драйверы Digma | обе камеры: код 10, `0xC000009E` (STATUS_DEVICE_POWER_FAILURE) |
| Windows 10 1511, заводские драйверы Digma | то же самое |

Шлейф осмотрен: видимых повреждений нет, обе камеры подключены одним разъёмом. Поэтому работу камер в Linux **никто не видел**. Файлы здесь — всё, что удалось подготовить; на планшете с исправными камерами они должны подойти, но это не проверено.

Что подготовлено и проверено:
- прошивка ISP `shisp_2401a0_v21.bin` (сборка `irci_stable_candrpv_0415_20150521_0458`) — драйвер её принимает;
- драйверы `atomisp`, `ipu-bridge`, `ov2680`, `gc0310` (исходники ядра 6.18.63) собираются вне дерева ядра и находят обе камеры: «Connected 2 cameras».

### ⚠️ Камеры и глубокий сон несовместимы

Модуль глубокого сна `intel_atomisp2_pm` (папка `power-isp/`) выключает процессор камер (ISP), чтобы во сне процессор уходил в S0i3. Драйвер камер `atomisp` использует то же устройство. Поэтому:
- **камеры включены** → глубокого сна нет, во сне батарея садится примерно на 3 % в час;
- **камеры выключены** → глубокий сон работает.

### Включить камеры

```sh
sh ~/digma-citi1804-linux/camera/enable.sh
sudo reboot
```

Скрипт скачивает прошивку ISP и проверяет её SHA-256, собирает модули (около 4 минут), убирает модуль глубокого сна и ставит модули камер. Проверка после перезагрузки: `ls /dev/video*`, `cam -l` (пакет `libcamera-tools`).

Исходники в `src/` — ядра 6.18.63. Для другой версии ядра скрипт остановится и попросит заменить их файлами той же версии.

### Выключить камеры и вернуть глубокий сон

```sh
sh ~/digma-citi1804-linux/camera/disable.sh
sudo reboot
```

Проверка: `cat /sys/bus/pci/devices/0000:00:03.0/power_state` должно показать `D3cold`.

### Состав

| Путь | Что это |
|---|---|
| `src/atomisp/` | драйвер ISP из `drivers/staging/media/atomisp` ядра 6.18.63; изменён только путь включаемых файлов в Makefile |
| `src/ov2680.c`, `src/gc0310.c` | драйверы камер; добавлен тестовый параметр инверсии GPIO (`invert_gpio`, `invert_gpios`), по умолчанию 0 — без изменений |
| `src/ipu-bridge.c` | связывает камеры из таблиц ACPI с драйвером ISP |
| `test/eldo2_on.c` | тестовый модуль: принудительно включает выход ELDO2 (1,8 В) контроллера питания AXP288. На моём планшете ACPI его не включал; включение не помогло |


---

## English

### Status

**The cameras are disabled by default.** On my tablet the cameras have a hardware fault, checked three ways:

| System | Result |
|---|---|
| Linux 6.18, drivers below | neither camera answers on I²C (`-121`) with power and clock on, for every GPIO polarity |
| Windows 10 1709, Digma factory drivers | both cameras: code 10, `0xC000009E` (STATUS_DEVICE_POWER_FAILURE) |
| Windows 10 1511, Digma factory drivers | the same |

The flex cable was inspected: no visible damage; both cameras share one connector. So **nobody has seen the cameras working on Linux**. These files are everything that could be prepared; they should work on a tablet with working cameras, but that is untested.

Prepared and checked:
- ISP firmware `shisp_2401a0_v21.bin` (build `irci_stable_candrpv_0415_20150521_0458`), accepted by the driver;
- `atomisp`, `ipu-bridge`, `ov2680`, `gc0310` (kernel 6.18.63 sources) build out of tree and find both cameras ("Connected 2 cameras").

### ⚠️ Cameras and deep sleep are mutually exclusive

The deep-sleep module `intel_atomisp2_pm` (`power-isp/`) powers off the camera ISP so the SoC reaches S0i3 in suspend. The camera driver `atomisp` uses the same device. So:
- **cameras enabled**: no deep sleep, the battery drains about 3 % per hour in suspend;
- **cameras disabled**: deep sleep works.

### Enable the cameras

```sh
sh ~/digma-citi1804-linux/camera/enable.sh
sudo reboot
```

The script downloads the ISP firmware and checks its SHA-256, builds the modules (about 4 minutes), removes the deep-sleep module and installs the camera modules. Check after reboot: `ls /dev/video*`, `cam -l` (package `libcamera-tools`).

The sources in `src/` are from kernel 6.18.63. For another kernel version the script stops and asks you to replace them with files of that version.

### Disable the cameras and restore deep sleep

```sh
sh ~/digma-citi1804-linux/camera/disable.sh
sudo reboot
```

Check: `cat /sys/bus/pci/devices/0000:00:03.0/power_state` must print `D3cold`.

### Contents

| Path | What it is |
|---|---|
| `src/atomisp/` | ISP driver from `drivers/staging/media/atomisp` of kernel 6.18.63; only the include path in the Makefile changed |
| `src/ov2680.c`, `src/gc0310.c` | sensor drivers with an added GPIO inversion test parameter (`invert_gpio`, `invert_gpios`), default 0 = unchanged |
| `src/ipu-bridge.c` | connects the cameras from the ACPI tables to the ISP driver |
| `test/eldo2_on.c` | test module: forces on the ELDO2 output (1.8 V) of the AXP288 PMIC. ACPI did not switch it on on my tablet; switching it on did not help |
