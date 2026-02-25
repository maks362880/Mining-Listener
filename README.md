# Mining-Listener
Lightweight Watchdog script for Windows mining rigs. Monitors NVIDIA GPU utilization and temperature, handles miner crashes, and prevents overheating.
A lightweight and reliable Watchdog script for monitoring mining rigs on Windows equipped with NVIDIA GPUs. The script monitors GPU utilization and temperatures, automatically taking action (such as rebooting the PC) in the event of a miner freeze, GPU driver crash, or critical overheating.

## ✨ Key Features

- **All-in-One File:** Written in PowerShell but wrapped in a convenient `.bat` executable. No need to mess with Windows execution policies — just double-click to run.
- **Smart Internet Check:** Before rebooting due to a drop in GPU usage, the script pings three independent servers (Google, Cloudflare, Yandex). If the internet is simply down, the rig will wait instead of entering an endless reboot loop.
- **Overheat Protection:** Visual temperature indicators (Green / Yellow / Red) and immediate emergency reboot when the critical temperature threshold is reached.
- **Crash Logging:** Whenever an issue occurs, the script carefully logs the state of all GPUs right before the crash.
- **Pre-Crash Screenshots:** Captures a screenshot of the desktop/console right before an emergency reboot (extremely helpful for diagnosing miner or pool errors).

---

## 🚀 Installation & Usage

1. Download the `Mining-Listener.bat` file and place it in any folder.
2. *(Optional)* For the screenshot feature to work, download the free `nircmd.exe` utility and place it in the same folder as the `.bat` file.
3. Open `Mining-Listener.bat` in any text editor (like Notepad) and configure the settings for your rig.
4. Add a shortcut of the `.bat` file to your Windows Startup folder.

---

## ⚙️ Configuration

At the top of the file, you will find the configuration block. Adjust these variables for your specific rig:

```powershell
$EXPECTED_GPUS  = 6     # Total number of GPUs expected in the rig
$MIN_UTIL       = 80    # Minimum utilization % (anything below means the GPU is not mining)
$TIMEOUT_SEC    = 2     # Timeout for GPU response (protects against frozen drivers)
$BOOT_DELAY     = 60    # Delay on Windows startup in seconds (allows miner and drivers to load)
$MAX_TEMP       = 80    # CRITICAL Overheat temp (C) — triggers immediate reboot
$TEMP_WARN      = 55    # Warning threshold (C) — temperature turns Yellow
$TEMP_HOT       = 65    # Danger threshold (C) — temperature turns Red
📝 Log File Example (mining_problems_log.txt)
Logs are kept compact and informative so you always know which GPU caused the crash:

text
25.02.2026 11:45:10 - REBOOT! Working GPUs: 5 out of 6.
--- GPU state before reboot ---
0, NVIDIA P106-100, 100%, 55
1, NVIDIA P106-100, 100%, 56
2, NVIDIA P106-100, 0%, 33
3, NVIDIA P106-100, 100%, 52
4, NVIDIA P106-100, 100%, 51
5, NVIDIA P106-100, 100%, 50
----------------------------------------
⚠️ Requirements
OS: Windows 10 / 11

Installed NVIDIA drivers (includes the required nvidia-smi.exe utility).

PowerShell 5.1+ (Built into Windows 10 by default).

⚖️ Third-Party Software License
This project uses the freeware utility NirCmd to capture screenshots.
All rights to NirCmd belong to Nir Sofer (NirSoft). The utility is distributed "As Is" (Freeware) in accordance with the author's official license.
Official website: https://www.nirsoft.net/utils/nircmd.html

Легкий и надежный скрипт (Watchdog) для мониторинга майнинг-ферм на базе ОС Windows и видеокарт NVIDIA. Скрипт отслеживает загрузку графических процессоров (GPU Utilization) и их температуру, автоматически принимая меры (перезагрузка ПК) при зависании майнера, отвале видеокарт или критическом перегреве.

## ✨ Главные особенности

- **Всё в одном файле:** Скрипт написан на PowerShell, но обернут в удобный запускаемый `.bat` файл. Никакой возни с политиками безопасности Windows — просто двойной клик.
- **Умная проверка интернета:** Перед тем как уйти в перезагрузку из-за падения нагрузки, скрипт проверяет пинг до трех независимых серверов (Google, Cloudflare, Yandex). Если просто пропал интернет — ферма не будет бесконечно перезагружаться.
- **Защита от перегрева:** Визуальная индикация температур (Зеленый / Желтый / Красный) и мгновенная экстренная перезагрузка при достижении критического порога.
- **Логирование:** При любом сбое скрипт аккуратно записывает в лог файл состояние всех видеокарт на момент аварии.
- **Скриншоты перед крашем:** Скрипт делает скриншот рабочего стола/консоли прямо перед аварийной перезагрузкой (помогает выявить ошибку пула или майнера).

---

## 🚀 Установка и запуск

1. Скачайте файл `Mining-Listener.bat` и поместите его в любую папку.
2. (Опционально) Для работы функции скриншотов скачайте утилиту `nircmd.exe` (бесплатная утилита от NirSoft) и положите её в ту же папку, где находится батник.
3. Откройте `Mining-Listener.bat` в любом текстовом редакторе (например, Блокнот) и отредактируйте блок настроек под вашу ферму.
4. Добавьте ярлык файла в автозагрузку Windows.

---

## ⚙️ Настройки скрипта

В самом начале файла находится блок переменных. Измените их под конфигурацию вашего рига:

```powershell
$EXPECTED_GPUS  = 6     # Ожидаемое количество видеокарт в риге
$MIN_UTIL       = 80    # Минимальная загрузка в % (если ниже — считается, что карта не майнит)
$TIMEOUT_SEC    = 2     # Таймаут ожидания ответа от карты (защита от глухого зависания драйвера)
$BOOT_DELAY     = 60    # Задержка в секундах при старте Windows (для прогрузки майнера и драйверов)
$MAX_TEMP       = 80    # Температура ПЕРЕГРЕВА (C) — вызывает немедленную перезагрузку ПК
$TEMP_WARN      = 55    # Порог предупреждения (C) — цвет температуры становится Жёлтым
$TEMP_HOT       = 65    # Порог опасности (C) — цвет температуры становится Красным
🛠 Как это работает (Логика)
Скрипт ждёт заданное время ($BOOT_DELAY) после старта Windows.

В цикле опрашивает утилиту nvidia-smi на предмет нагрузки и температуры каждой карты.

Если нагрузка одной или нескольких карт падает ниже $MIN_UTIL (например, 80%):

Скрипт проверяет наличие интернета.

Если интернета нет — просто ждет его появления.

Если интернет есть — ждет 20 секунд и делает контрольный замер.

Если контрольный замер подтверждает падение нагрузки (или зависание) — делает скриншот, пишет лог и жестко перезагружает ПК.

Если температура любой из карт превышает $MAX_TEMP — скрипт уходит в экстренную перезагрузку немедленно, минуя контрольные ожидания.

📝 Пример лог-файла (mining_problems_log.txt)
Логи получаются компактными и информативными. Вы всегда будете знать, из-за какой карты произошел сбой:

text
25.02.2026 11:45:10 - ПЕРЕЗАГРУЗКА! Работало карт: 5 из 6.
--- Состояние карт перед перезагрузкой ---
0, NVIDIA P106-100, 100%, 55
1, NVIDIA P106-100, 100%, 56
2, NVIDIA P106-100, 0%, 33
3, NVIDIA P106-100, 100%, 52
4, NVIDIA P106-100, 100%, 51
5, NVIDIA P106-100, 100%, 50
----------------------------------------
⚠️ Требования
Операционная система: Windows 10 / 11

Установленные драйверы NVIDIA (утилита nvidia-smi.exe поставляется вместе с ними).

PowerShell 5.1+ (Встроен в Windows 10 по умолчанию).

## ⚖️ Лицензия на стороннее ПО
В данном проекте для создания скриншотов используется бесплатная утилита **NirCmd**. 
Все права на NirCmd принадлежат Ниру Соферу (Nir Sofer / NirSoft). Утилита распространяется «как есть» (Freeware) в соответствии с официальной лицензией автора. 
Официальный сайт: [https://www.nirsoft.net/utils/nircmd.html](https://www.nirsoft.net/utils/nircmd.html)


