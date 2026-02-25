<# :
@echo off
setlocal
mode con cols=41 lines=15
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
goto :eof
#>

# --- НАСТРОЙКИ ФЕРМЫ ---
$EXPECTED_GPUS  = 6     # Сколько всего карт в риге
$MIN_UTIL       = 80    # Минимальная загрузка в %
$TIMEOUT_SEC    = 2     # Сколько секунд ждать ответа от карты
$BOOT_DELAY     = 60    # Задержка при старте Windows (сек)
$MAX_TEMP       = 80    # Температура перегрева — перезагрузка (C)
$TEMP_WARN      = 55    # С этой температуры цвет станет жёлтым (C)
$TEMP_HOT       = 65    # С этой температуры цвет станет красным (C)

$CurrentDir = $env:SCRIPT_DIR.TrimEnd('\')
$LogFile    = Join-Path $CurrentDir "mining_problems_log.txt"
$StartTime  = Get-Date

function Write-Log($Message) {
    $Stamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Stamp - $Message" -Encoding UTF8
}

function Take-Screenshot {
    $ScrPath = Join-Path $CurrentDir "Scr"
    if (-not (Test-Path $ScrPath)) { New-Item -ItemType Directory -Path $ScrPath | Out-Null }
    $FileName = (Get-Date).ToString("yyyy.MM.dd HH-mm-ss") + ".png"
    $FilePath = Join-Path $ScrPath $FileName
    $Nircmd  = Join-Path $CurrentDir "nircmd.exe"
    $Nircmdc = Join-Path $CurrentDir "nircmdc.exe"
    $ExeToUse = $null
    if (Test-Path $Nircmd) { $ExeToUse = $Nircmd }
    elseif (Test-Path $Nircmdc) { $ExeToUse = $Nircmdc }
    if ($ExeToUse) {
        & $ExeToUse savescreenshot $FilePath
        Write-Host "Скриншот сохранен: $FileName" -ForegroundColor Yellow
    } else {
        Write-Host "nircmd.exe не найден!" -ForegroundColor Red
    }
}

function Find-NvidiaSmi {
    $paths = @(
        (Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue).Source,
        "$env:PROGRAMFILES\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    )
    $driverStore = "$env:WINDIR\System32\DriverStore\FileRepository"
    if (Test-Path $driverStore) {
        $paths += Get-ChildItem -Path $driverStore -Filter "nvidia-smi.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }
    foreach ($p in $paths) {
        if ($null -ne $p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Wait-Compact($Seconds) {
    for ($i = $Seconds; $i -ge 0; $i--) {
        $Uptime = (Get-Date) - $StartTime
        $UptStr = "{0:hh}:{0:mm}:{0:ss}" -f $Uptime
        $Percent = 0
        if ($Seconds -gt 0) { $Percent = [math]::Round((($Seconds - $i) / $Seconds) * 100) }
        $BarLen = 25
        $Filled = [math]::Round(($Percent / 100) * $BarLen)
        $Empty  = $BarLen - $Filled
        $Bars   = [string]::new('#', $Filled)
        $Spaces = [string]::new('-', $Empty)
        Write-Host "`r[$Bars$Spaces] $i сек." -NoNewline -ForegroundColor Cyan
        Write-Host "`nВремя скрипта: $UptStr    `r" -NoNewline -ForegroundColor White
        if ($i -gt 0) {
            [Console]::CursorTop -= 1
            Start-Sleep -Seconds 1
        }
    }
    Write-Host "`n"
}

# === СТАРТОВАЯ ЗАДЕРЖКА ===
Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   ЗАГРУЗКА И ИНИЦИАЛИЗАЦИЯ...           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Wait-Compact -Seconds $BOOT_DELAY

# --- ОСНОВНОЙ ЦИКЛ ---
while ($true) {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "       MINING LISTENER V1.1              " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    $smi = Find-NvidiaSmi
    if (-not $smi) {
        Write-Host "nvidia-smi.exe не найден!" -ForegroundColor Red
        Wait-Compact -Seconds 10
        continue
    }

    $goodCount  = 0
    $totalUtil  = 0
    $seenCount  = 0
    $overHeatGpu = -1

    for ($i = 0; $i -lt ($EXPECTED_GPUS + 2); $i++) {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $smi
        $process.StartInfo.Arguments = "--id=$i --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits"
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.CreateNoWindow = $true
        $null   = $process.Start()
        $exited = $process.WaitForExit($TIMEOUT_SEC * 1000)

        if ($exited) {
            $output = $process.StandardOutput.ReadToEnd().Trim()
            if ($output -match '^(\d+),\s*(\d+)$') {
                $util = [int]$matches[1]
                $temp = [int]$matches[2]
                $seenCount++
                $totalUtil += $util

                # УПРОЩЕННАЯ ЛОГИКА ЦВЕТОВ БЕЗ ФИГУРНЫХ СКОБОК (switch)
                $tc = "Red"
                switch ($temp) {
                    { $_ -lt $TEMP_WARN } { $tc = "Green"; break }
                    { $_ -lt $TEMP_HOT }  { $tc = "Yellow"; break }
                }

                # ПРОВЕРКА ПЕРЕГРЕВА БЕЗ ВЛОЖЕННОГО IF
                switch ($temp) {
                    { $_ -ge $MAX_TEMP } { $overHeatGpu = $i }
                }

                # ПРОСТОЙ ВЫВОД НАГРУЗКИ (как было в manual8)
                if ($util -ge $MIN_UTIL) {
                    $goodCount++
                    Write-Host "GPU $i`: $util%   " -NoNewline -ForegroundColor Green
                    Write-Host "${temp}C" -ForegroundColor $tc
                } else {
                    Write-Host "GPU $i`: $util%   " -NoNewline -ForegroundColor Red
                    Write-Host "${temp}C" -ForegroundColor $tc
                }
            }
        } else {
            try { $process.Kill() } catch {}
        }
    }

    if ($seenCount -eq 0) {
        Write-Host "Видеокарты не отвечают!" -ForegroundColor Red
        $goodCount = -1
    } else {
        $avg = [math]::Round($totalUtil / $seenCount)
        Write-Host "`nСр. загрузка: $avg% | В норме: $goodCount из $EXPECTED_GPUS" -ForegroundColor Cyan
    }

    # === ПЕРЕГРЕВ ===
    if ($overHeatGpu -ge 0) {
        Write-Host "ПЕРЕГРЕВ! GPU $overHeatGpu >= ${MAX_TEMP}C!" -ForegroundColor White -BackgroundColor DarkRed
        Take-Screenshot
        Write-Log "ПЕРЕГРЕВ! GPU $overHeatGpu достиг >= ${MAX_TEMP}C. Перезагрузка."
        try {
            $cmdOut = & $smi --query-gpu=index,name,utilization.gpu,temperature.gpu --format=csv,noheader
            Add-Content -Path $LogFile -Value "--- Состояние карт при перегреве ---" -Encoding UTF8
            Add-Content -Path $LogFile -Value $cmdOut -Encoding UTF8
            Add-Content -Path $LogFile -Value "----------------------------------------" -Encoding UTF8
        } catch {}
        Wait-Compact -Seconds 10
        Restart-Computer -Force
        exit
    }

    if ($goodCount -ge $EXPECTED_GPUS) {
        Write-Host "--- МАЙНИНГ РАБОТАЕТ ИСПРАВНО ---" -ForegroundColor Green
        Wait-Compact -Seconds 60
        continue
    }

    Write-Host "ПАДЕНИЕ НАГРУЗКИ / ОТВАЛ КАРТЫ!" -ForegroundColor White -BackgroundColor Red

    # === ТРОЙНАЯ ПРОВЕРКА ИНТЕРНЕТА ===
    $ping1 = Test-Connection -ComputerName 8.8.8.8   -Count 2 -Quiet
    $ping2 = Test-Connection -ComputerName 1.1.1.1   -Count 2 -Quiet
    $ping3 = Test-Connection -ComputerName 77.88.8.8 -Count 2 -Quiet
    if (-not ($ping1 -or $ping2 -or $ping3)) {
        Write-Host "Нет интернета. Ожидание..." -ForegroundColor DarkYellow
        Write-Log "Нет интернета."
        Wait-Compact -Seconds 15
        continue
    }

    Write-Host "Интернет стабилен. Контроль..." -ForegroundColor Yellow
    Wait-Compact -Seconds 20

    Write-Host "Контрольный опрос карт..." -ForegroundColor Yellow
    $recheckGoodCount = 0
    for ($i = 0; $i -lt ($EXPECTED_GPUS + 2); $i++) {
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo.FileName = $smi
        $p.StartInfo.Arguments = "--id=$i --query-gpu=utilization.gpu --format=csv,noheader,nounits"
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.CreateNoWindow = $true
        $null = $p.Start()
        if ($p.WaitForExit($TIMEOUT_SEC * 1000)) {
            $out = $p.StandardOutput.ReadToEnd().Trim()
            if ($out -match '^\d+$' -and [int]$out -ge $MIN_UTIL) { $recheckGoodCount++ }
        } else {
            try { $p.Kill() } catch {}
        }
    }

    if ($recheckGoodCount -ge $EXPECTED_GPUS) {
        Write-Host "Контрольная проверка пройдена!" -ForegroundColor Green
        Write-Log "Ложная тревога (восстановлено)."
        Wait-Compact -Seconds 10
        continue
    }

    Write-Host "АВАРИЙНАЯ ПЕРЕЗАГРУЗКА ПК" -ForegroundColor White -BackgroundColor DarkRed
    Take-Screenshot
    Write-Log "ПЕРЕЗАГРУЗКА! Работало карт: $goodCount из $EXPECTED_GPUS."
    try {
        $cmdOut = & $smi --query-gpu=index,name,utilization.gpu,temperature.gpu --format=csv,noheader
        Add-Content -Path $LogFile -Value "--- Состояние карт перед перезагрузкой ---" -Encoding UTF8
        Add-Content -Path $LogFile -Value $cmdOut -Encoding UTF8
        Add-Content -Path $LogFile -Value "----------------------------------------" -Encoding UTF8
    } catch {}

    Wait-Compact -Seconds 10
    Restart-Computer -Force
    exit
}
