$ProgressPreference = 'Continue'

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "You are not running as Administrator. Restarting with elevated privileges."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Start-Sleep 2
    exit
}

$base = Read-Host "Enter the directory where 'Register_backup' should be created"

if ([string]::IsNullOrWhiteSpace($base)) {
    Write-Host "Invalid path. Exiting."
    exit
}

if (-not (Test-Path $base)) {
    try {
        New-Item -Path $base -ItemType Directory -Force | Out-Null
    } catch {
        Write-Host "Error accessing base directory."
        exit
    }
}

$backupRoot = Join-Path $base "Register_backup"
New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null

$logFile = Join-Path $backupRoot "export.log"
"Start: $(Get-Date)" | Out-File $logFile -Encoding UTF8

Write-Host "Folder created: $backupRoot"
Read-Host "Press Enter to continue"

$hives = @("HKLM","HKCU","HKCR","HKU","HKCC")

while ($true) {
    Write-Host ""
    Write-Host "1. Export in any files"
    Write-Host "2. Export in one file"
    Write-Host "3. Exit and delete 'Register_backup' folder"
    Write-Host "4. Exit"

    $choice = Read-Host "Select option"

    switch ($choice) {
        '1' {
            $i = 0
            foreach ($hive in $hives) {
                $i++
                $percent = [int](($i / $hives.Count) * 100)
                Write-Progress -Activity "Exporting registry" -Status "$hive" -PercentComplete $percent

                $file = Join-Path $backupRoot "$hive.reg"
                & reg.exe export $hive $file /y 2>$null

                if ($LASTEXITCODE -eq 0) {
                    "$hive exported successfully" | Add-Content $logFile
                } else {
                    "$hive export failed" | Add-Content $logFile
                }
            }
            Write-Progress -Activity "Exporting registry" -Completed
            Read-Host "Press Enter to return to menu"
        }

        '2' {
            $final = Join-Path $backupRoot "full_registry_backup.reg"
            "Windows Registry Editor Version 5.00" | Out-File $final -Encoding ASCII

            $i = 0
            foreach ($hive in $hives) {
                $i++
                $percent = [int](($i / $hives.Count) * 100)
                Write-Progress -Activity "Exporting registry" -Status "$hive" -PercentComplete $percent

                $tmp = Join-Path $backupRoot "$hive.tmp"
                & reg.exe export $hive $tmp /y 2>$null

                if (Test-Path $tmp) {
                    Get-Content $tmp | Select-Object -Skip 1 | Add-Content $final
                    Remove-Item $tmp -Force
                    "$hive exported successfully" | Add-Content $logFile
                } else {
                    "$hive export failed" | Add-Content $logFile
                }
            }
            Write-Progress -Activity "Exporting registry" -Completed
            Write-Host "All hives exported into one file"
            Read-Host "Press Enter to return to menu"
        }

        '3' {
            Write-Host "Deleting folder and exiting"
            try {
                Remove-Item $backupRoot -Recurse -Force
            } catch {}
            exit
        }

        '4' {
            exit
        }

        default {
            Write-Host "Invalid option"
        }
    }
}