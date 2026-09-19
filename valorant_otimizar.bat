@echo off
setlocal enableextensions
title valorant otimizador
cd /d "%~dp0"

rem hklm falha sem admin
fltmc >nul 2>&1
if errorlevel 1 (
    echo rode como administrador: botao direito no arquivo, executar como administrador
    pause
    exit /b 1
)

rem ajuste aqui se o valorant estiver em outra pasta
set "RIOT_DIR=C:\Riot Games"
set "VAL_EXE=%RIOT_DIR%\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe"

set "BK=%~dp0valorant_backup"
set "IFEO=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions"
set "MMCSS=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

cls
echo.
echo  valorant otimizador
echo.
echo  [1] aplicar
echo  [2] reverter pro padrao do windows
echo  [3] sair
echo.
choice /c 123 /n /m " escolha: "
if errorlevel 3 exit /b 0
if errorlevel 2 goto reverter

:aplicar
mkdir "%BK%" 2>nul

rem backup dos ramos que o script altera, restaura com duplo clique no .reg
call :bk "HKCU\System\GameConfigStore" gameconfigstore
call :bk "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" gamedvr
call :bk "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" layers
call :bk "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" bgapps
call :bk "%MMCSS%" systemprofile

rem game dvr grava em segundo plano e gasta gpu, desligado
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul

rem game mode ligado: segura update de driver e aviso de reinicio durante a partida
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul

rem fullscreen exclusivo classico em vez do modo otimizado do windows
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f >nul
reg add "HKCU\System\GameConfigStore" /v GameDVR_DXGIHonorFSEWindowsCompatible /t REG_DWORD /d 1 /f >nul
if exist "%VAL_EXE%" reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%VAL_EXE%" /t REG_SZ /d "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" /f >nul
if not exist "%VAL_EXE%" echo aviso: exe do valorant nao encontrado, ajuste VAL_EXE no topo do script

rem mmcss: tira o limite de rede e reduz a reserva de cpu pra tarefas de fundo
reg add "%MMCSS%" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f >nul
reg add "%MMCSS%" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul
reg add "%MMCSS%\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "High" /f >nul

rem prioridade alta aplicada pelo kernel na criacao do processo, sem depender de handle externo (o vanguard restringe)
reg add "%IFEO%" /v CpuPriorityClass /t REG_DWORD /d 3 /f >nul

rem exclui a pasta da riot do scan em tempo real do defender, menos io durante o jogo
powershell -NoProfile -Command "Add-MpPreference -ExclusionPath '%RIOT_DIR%'" >nul 2>&1

rem apps uwp em segundo plano gastam ram e cpu a toa
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul

echo.
echo pronto. reinicie o pc pra tudo valer.
echo backup dos ramos alterados: %BK%
pause
exit /b 0

:reverter

rem valores abaixo voltam pro padrao do windows, nao pro que estava antes de aplicar (pra isso use os .reg do backup)
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 1 /f >nul
reg delete "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /f >nul 2>&1
reg delete "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /f >nul 2>&1
reg delete "HKCU\System\GameConfigStore" /v GameDVR_DXGIHonorFSEWindowsCompatible /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 1 /f >nul
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%VAL_EXE%" /f >nul 2>&1

reg add "%MMCSS%" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f >nul
reg add "%MMCSS%" /v SystemResponsiveness /t REG_DWORD /d 20 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "Priority" /t REG_DWORD /d 2 /f >nul
reg add "%MMCSS%\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "Medium" /f >nul
reg add "%MMCSS%\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "Normal" /f >nul

reg delete "%IFEO%" /f >nul 2>&1
powershell -NoProfile -Command "Remove-MpPreference -ExclusionPath '%RIOT_DIR%'" >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f >nul

echo.
echo revertido. reinicie o pc.
pause
exit /b 0

:bk
rem so guarda o backup original, nao sobrescreve em execucoes seguintes
if exist "%BK%\%~2.reg" exit /b
reg export "%~1" "%BK%\%~2.reg" /y >nul 2>&1
exit /b
