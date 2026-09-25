# ============================================================
#  VALORANT OTIMIZADOR v3 - painel grafico
#  Interface com checkboxes em vez de menu de terminal.
#  Continua um arquivo unico: pede UAC sozinho, sem .bat, e
#  esconde a janela de console por tras do painel.
#
#  Cada ajuste marcado so e aplicado quando "APLICAR
#  SELECIONADOS" e clicado. Antes de qualquer mudanca de
#  registro, a chave original e exportada pra pasta
#  "valorant_backup" (um .reg por chave), do lado deste script.
#
#  Nota sobre a exclusao no Windows Defender: tira a pasta da
#  Riot do escaneamento em tempo real, reduzindo a protecao do
#  antivirus so ali, em troca de menos I/O durante o jogo.
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$ErrorActionPreference = "SilentlyContinue"

# ----------------------- CONFIGURACAO -----------------------
$ScriptPath = $PSCommandPath
if (-not $ScriptPath) { $ScriptPath = $MyInvocation.MyCommand.Path }
$ScriptDir  = Split-Path -Parent $ScriptPath
$BackupDir  = Join-Path $ScriptDir "valorant_backup"
$ConfigFile = Join-Path $ScriptDir "config.json"
$RelExePath = "VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe"

$IFEO_KEY    = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions"
$MMCSS_KEY   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
$GAMES_KEY   = "$MMCSS_KEY\Tasks\Games"
$GFXDRV_KEY  = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$LAYERS_KEY  = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
$GAMECFG_KEY = "HKCU:\System\GameConfigStore"
$GAMEDVR_KEY = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
$BGAPPS_KEY  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
$GAMEBAR_KEY = "HKCU:\Software\Microsoft\GameBar"

$ULTIMATE_GUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"

$BG_HOGS = @(
    "Discord","DiscordCanary","DiscordPTB","Spotify",
    "chrome","msedge","firefox","opera","brave",
    "EpicGamesLauncher","EAApp","Origin","Battle.net",
    "Steam","OneDrive","Dropbox","Teams","Slack","skype"
)

# ----------------------- REGISTRO / BACKUP -----------------------

function Backup-Key([string]$path, [string]$name) {
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
    $file = Join-Path $BackupDir "$name.reg"
    if (Test-Path $file) { return }
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    $regPath = $path.Replace("HKLM:\", "HKLM\").Replace("HKCU:\", "HKCU\")
    reg.exe export "$regPath" "$file" /y *> $null
}

function Set-Reg([string]$path, [string]$name, $value, [string]$type = "DWord") {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
}

function Get-Reg([string]$path, [string]$name) {
    try { return (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name }
    catch { return $null }
}

function Remove-Reg([string]$path, [string]$name) {
    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
}

function Get-Guid([string]$text) {
    if ($text -match "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})") { return $Matches[1] }
    return $null
}

function Save-PowerPlanOriginal {
    $file = Join-Path $BackupDir "power_plan_anterior.txt"
    if (Test-Path $file) { return }
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
    $txt = powercfg /getactivescheme | Out-String
    $guid = Get-Guid $txt
    if ($guid) { Set-Content -Path $file -Value $guid }
}

function Load-Config {
    if (Test-Path $ConfigFile) {
        try {
            $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($cfg.RiotDir) { return $cfg.RiotDir }
        } catch {}
    }
    return "C:\Riot Games"
}

function Save-Config([string]$riotDir) {
    @{ RiotDir = $riotDir } | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
}

# ----------------------- ATALHO SEM UAC -----------------------
# Cria uma tarefa agendada (privilegio maximo) + atalho na area de
# trabalho. Como o painel ja roda elevado nesse ponto, nao precisa
# pedir UAC de novo pra criar a tarefa - so acontece essa vez.

$AtalhoTaskName = "ValorantOtimizador"

function Test-AtalhoInstalado {
    Import-Module ScheduledTasks -ErrorAction SilentlyContinue
    return [bool](Get-ScheduledTask -TaskName $AtalhoTaskName -ErrorAction SilentlyContinue)
}

function New-Atalho {
    Import-Module ScheduledTasks -ErrorAction SilentlyContinue
    $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)

    Unregister-ScheduledTask -TaskName $AtalhoTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $AtalhoTaskName -Action $action -Principal $principal -Settings $settings | Out-Null

    $desktop      = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Valorant Otimizador.lnk"
    $wsh          = New-Object -ComObject WScript.Shell
    $shortcut     = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath       = Join-Path $env:WINDIR "System32\schtasks.exe"
    $shortcut.Arguments        = "/run /tn `"$AtalhoTaskName`""
    $shortcut.WorkingDirectory = $ScriptDir
    $shortcut.WindowStyle      = 7
    $shortcut.IconLocation     = (Join-Path $env:WINDIR "System32\shell32.dll") + ",13"
    $shortcut.Description      = "Abre o Valorant Otimizador direto como administrador"
    $shortcut.Save()
}

function Remove-Atalho {
    Import-Module ScheduledTasks -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $AtalhoTaskName -Confirm:$false -ErrorAction SilentlyContinue
    $desktop      = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Valorant Otimizador.lnk"
    if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
}

# ----------------------- ADMIN / CONSOLE -----------------------

function Hide-Console {
    Add-Type -Name "ConsoleWindow" -Namespace "NativeMethods" -MemberDefinition '
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    '
    $h = [NativeMethods.ConsoleWindow]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [NativeMethods.ConsoleWindow]::ShowWindow($h, 0) | Out-Null }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    try {
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$ScriptPath`"") `
            -Verb RunAs -ErrorAction Stop | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Precisa de permissao de administrador. Clique com o botao direito no arquivo e escolha 'Executar com PowerShell', e aceite o UAC.",
            "Valorant Otimizador") | Out-Null
    }
    exit
}

Hide-Console

$RiotDir = Load-Config
$ValExe  = Join-Path $RiotDir $RelExePath
if (-not (Test-Path $ValExe)) {
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "VALORANT nao encontrado em C:\Riot Games - selecione a pasta Riot Games"
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $RiotDir = $fbd.SelectedPath
        $ValExe  = Join-Path $RiotDir $RelExePath
        Save-Config $RiotDir
    }
}

# ----------------------- LISTA DE AJUSTES -----------------------

$tweaks = @(
    @{ Label = "Desativar Game DVR"
       StatusCheck = { (Get-Reg $GAMECFG_KEY "GameDVR_Enabled") -eq 0 }
       Apply = {
           Backup-Key $GAMECFG_KEY "gameconfigstore"
           Backup-Key $GAMEDVR_KEY "gamedvr"
           Set-Reg $GAMECFG_KEY "GameDVR_Enabled" 0
           Set-Reg $GAMEDVR_KEY "AppCaptureEnabled" 0
       }
    },
    @{ Label = "Ativar Game Mode"
       StatusCheck = { (Get-Reg $GAMEBAR_KEY "AutoGameModeEnabled") -eq 1 }
       Apply = {
           Set-Reg $GAMEBAR_KEY "AllowAutoGameMode" 1
           Set-Reg $GAMEBAR_KEY "AutoGameModeEnabled" 1
       }
    },
    @{ Label = "Fullscreen exclusivo classico"
       StatusCheck = { (Get-Reg $GAMECFG_KEY "GameDVR_FSEBehaviorMode") -eq 2 }
       Apply = {
           Backup-Key $GAMECFG_KEY "gameconfigstore"
           Backup-Key $LAYERS_KEY "layers"
           Set-Reg $GAMECFG_KEY "GameDVR_FSEBehaviorMode" 2
           Set-Reg $GAMECFG_KEY "GameDVR_HonorUserFSEBehaviorMode" 1
           Set-Reg $GAMECFG_KEY "GameDVR_DXGIHonorFSEWindowsCompatible" 1
           if (Test-Path $ValExe) {
               Set-Reg $LAYERS_KEY $ValExe "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" "String"
           }
       }
    },
    @{ Label = "Ajustar MMCSS (rede/CPU p/ jogos)"
       StatusCheck = { (Get-Reg $MMCSS_KEY "SystemResponsiveness") -eq 0 }
       Apply = {
           Backup-Key $MMCSS_KEY "systemprofile"
           Set-Reg $MMCSS_KEY "NetworkThrottlingIndex" 0xffffffff
           Set-Reg $MMCSS_KEY "SystemResponsiveness" 0
           Set-Reg $GAMES_KEY "GPU Priority" 8
           Set-Reg $GAMES_KEY "Priority" 6
           Set-Reg $GAMES_KEY "Scheduling Category" "High" "String"
           Set-Reg $GAMES_KEY "SFIO Priority" "High" "String"
       }
    },
    @{ Label = "Prioridade alta de CPU (VALORANT)"
       StatusCheck = { (Get-Reg $IFEO_KEY "CpuPriorityClass") -eq 3 }
       Apply = {
           Backup-Key $IFEO_KEY "ifeo"
           Set-Reg $IFEO_KEY "CpuPriorityClass" 3
       }
    },
    @{ Label = "Excluir pasta da Riot do Defender"
       StatusCheck = { (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath -contains $RiotDir }
       Apply = {
           try { Add-MpPreference -ExclusionPath $RiotDir -ErrorAction Stop } catch {}
       }
    },
    @{ Label = "Bloquear apps UWP em 2o plano"
       StatusCheck = { (Get-Reg $BGAPPS_KEY "GlobalUserDisabled") -eq 1 }
       Apply = {
           Backup-Key $BGAPPS_KEY "bgapps"
           Set-Reg $BGAPPS_KEY "GlobalUserDisabled" 1
       }
    },
    @{ Label = "Ultimate Performance (energia)"
       StatusCheck = { (powercfg /getactivescheme | Out-String) -match "Ultimate Performance" }
       Apply = {
           Save-PowerPlanOriginal
           $dupTxt = powercfg /duplicatescheme $ULTIMATE_GUID | Out-String
           $novoGuid = Get-Guid $dupTxt
           if ($novoGuid) { powercfg /setactive $novoGuid }
       }
    },
    @{ Label = "GPU Scheduling (HAGS)"
       StatusCheck = { (Get-Reg $GFXDRV_KEY "HwSchMode") -eq 2 }
       Apply = {
           Backup-Key $GFXDRV_KEY "graphicsdrivers"
           Set-Reg $GFXDRV_KEY "HwSchMode" 2
       }
    },
    @{ Label = "Desativar Nagle (rede)"
       StatusCheck = {
           $r = $false
           Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
               $p = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($_.InterfaceGuid)"
               if ((Get-Reg $p "TcpAckFrequency") -eq 1) { $r = $true }
           }
           $r
       }
       Apply = {
           Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
               $guid = $_.InterfaceGuid
               $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
               if (Test-Path $ifPath) {
                   Backup-Key $ifPath "nagle_$guid"
                   Set-Reg $ifPath "TcpAckFrequency" 1
                   Set-Reg $ifPath "TCPNoDelay" 1
               }
           }
       }
    }
)

# ----------------------- VISUAL -----------------------

$formWidth  = 560
$formHeight = 560

$colorBg     = [System.Drawing.Color]::FromArgb(255, 15, 15, 18)
$colorPanel  = [System.Drawing.Color]::FromArgb(255, 24, 24, 28)
$colorAccent = [System.Drawing.Color]::FromArgb(255, 255, 70, 85)
$colorText   = [System.Drawing.Color]::WhiteSmoke
$colorMuted  = [System.Drawing.Color]::FromArgb(255, 150, 150, 155)

$fontTitle = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$fontBtn   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontItem  = New-Object System.Drawing.Font("Segoe UI", 9)

# ----------------------- FORM -----------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Valorant Otimizador"
$form.Size = New-Object System.Drawing.Size($formWidth, $formHeight)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $colorBg
$form.ForeColor = $colorText

Add-Type -Name "WindowDrag" -Namespace "NativeMethods" -MemberDefinition '
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
'

function New-DragHandler([System.Windows.Forms.Form]$targetForm) {
    $sb = {
        [NativeMethods.WindowDrag]::ReleaseCapture() | Out-Null
        [NativeMethods.WindowDrag]::SendMessage($targetForm.Handle, 0xA1, 0x2, 0) | Out-Null
    }
    return $sb.GetNewClosure()
}

$dragHandler = New-DragHandler $form

$titleBar = New-Object System.Windows.Forms.Panel
$titleBar.Location = New-Object System.Drawing.Point(0, 0)
$titleBar.Size = New-Object System.Drawing.Size($formWidth, 30)
$titleBar.BackColor = $colorPanel
$titleBar.Add_MouseDown($dragHandler)
$form.Controls.Add($titleBar)

$lblTitleBar = New-Object System.Windows.Forms.Label
$lblTitleBar.Text = "VALORANT OTIMIZADOR"
$lblTitleBar.ForeColor = $colorMuted
$lblTitleBar.Font = $fontBtn
$lblTitleBar.Location = New-Object System.Drawing.Point(12, 6)
$lblTitleBar.Size = New-Object System.Drawing.Size(300, 20)
$lblTitleBar.Add_MouseDown($dragHandler)
$titleBar.Controls.Add($lblTitleBar)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "X"
$btnClose.FlatStyle = "Flat"
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.BackColor = $colorAccent
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.Size = New-Object System.Drawing.Size(30, 30)
$btnClose.Location = New-Object System.Drawing.Point(($formWidth - 30), 0)
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

$btnMin = New-Object System.Windows.Forms.Button
$btnMin.Text = "-"
$btnMin.FlatStyle = "Flat"
$btnMin.FlatAppearance.BorderSize = 0
$btnMin.BackColor = $colorPanel
$btnMin.ForeColor = $colorText
$btnMin.Size = New-Object System.Drawing.Size(30, 30)
$btnMin.Location = New-Object System.Drawing.Point(($formWidth - 60), 0)
$btnMin.Add_Click({ $form.WindowState = "Minimized" })
$titleBar.Controls.Add($btnMin)

$content = New-Object System.Windows.Forms.Panel
$content.Location = New-Object System.Drawing.Point(0, 30)
$content.Size = New-Object System.Drawing.Size($formWidth, ($formHeight - 30))
$content.BackColor = $colorBg
$form.Controls.Add($content)

$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "VALORANT"
$lbl1.Font = $fontTitle
$lbl1.ForeColor = $colorText
$lbl1.TextAlign = "MiddleCenter"
$lbl1.Location = New-Object System.Drawing.Point(0, 12)
$lbl1.Size = New-Object System.Drawing.Size($formWidth, 35)
$content.Controls.Add($lbl1)

$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "OTIMIZADOR"
$lbl2.Font = $fontTitle
$lbl2.ForeColor = $colorAccent
$lbl2.TextAlign = "MiddleCenter"
$lbl2.Location = New-Object System.Drawing.Point(0, 46)
$lbl2.Size = New-Object System.Drawing.Size($formWidth, 35)
$content.Controls.Add($lbl2)

$gbLeft = New-Object System.Windows.Forms.GroupBox
$gbLeft.Text = "ACOES RAPIDAS"
$gbLeft.ForeColor = $colorMuted
$gbLeft.Font = $fontBtn
$gbLeft.BackColor = $colorBg
$gbLeft.Location = New-Object System.Drawing.Point(20, 100)
$gbLeft.Size = New-Object System.Drawing.Size(180, 360)
$content.Controls.Add($gbLeft)

function New-ActionButton([string]$text, [int]$y) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Font = $fontBtn
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = $colorAccent
    $b.FlatAppearance.BorderSize = 1
    $b.BackColor = $colorPanel
    $b.ForeColor = $colorText
    $b.Location = New-Object System.Drawing.Point(15, $y)
    $b.Size = New-Object System.Drawing.Size(150, 36)
    return $b
}

$btnBoost = New-ActionButton "BOOST AGORA" 30
$gbLeft.Controls.Add($btnBoost)

$btnStatus = New-ActionButton "STATUS" 78
$gbLeft.Controls.Add($btnStatus)

$btnRevert = New-ActionButton "REVERTER" 126
$gbLeft.Controls.Add($btnRevert)

$btnAtalho = New-ActionButton $(if (Test-AtalhoInstalado) { "REMOVER ATALHO" } else { "CRIAR ATALHO" }) 174
$gbLeft.Controls.Add($btnAtalho)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblInfo.ForeColor = $colorMuted
$lblInfo.Location = New-Object System.Drawing.Point(15, 225)
$lblInfo.Size = New-Object System.Drawing.Size(150, 60)
$achouTxt   = if (Test-Path $ValExe) { "VALORANT encontrado" } else { "VALORANT nao encontrado" }
$atalhoTxt  = if (Test-AtalhoInstalado) { "atalho sem UAC: instalado" } else { "atalho sem UAC: nao instalado" }
$lblInfo.Text = "$achouTxt`n$atalhoTxt"
$gbLeft.Controls.Add($lblInfo)

$gbRight = New-Object System.Windows.Forms.GroupBox
$gbRight.Text = "AJUSTES"
$gbRight.ForeColor = $colorMuted
$gbRight.Font = $fontBtn
$gbRight.BackColor = $colorBg
$gbRight.Location = New-Object System.Drawing.Point(210, 100)
$gbRight.Size = New-Object System.Drawing.Size(330, 360)
$content.Controls.Add($gbRight)

$y = 26
foreach ($t in $tweaks) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $t.Label
    $cb.Font = $fontItem
    $cb.ForeColor = $colorText
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.Size = New-Object System.Drawing.Size(300, 20)
    $cb.Checked = [bool](& $t.StatusCheck)
    $gbRight.Controls.Add($cb)
    $t.Control = $cb
    $y += 26
}

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "APLICAR SELECIONADOS"
$btnApply.Font = $fontBtn
$btnApply.FlatStyle = "Flat"
$btnApply.FlatAppearance.BorderSize = 0
$btnApply.BackColor = $colorAccent
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.Location = New-Object System.Drawing.Point(15, ($y + 6))
$btnApply.Size = New-Object System.Drawing.Size(300, 36)
$gbRight.Controls.Add($btnApply)

# ----------------------- JANELA DE STATUS -----------------------

function Show-StatusWindow {
    foreach ($t in $tweaks) { $t.Control.Checked = [bool](& $t.StatusCheck) }

    $sf = New-Object System.Windows.Forms.Form
    $sf.Text = "Status"
    $sf.Size = New-Object System.Drawing.Size(420, 470)
    $sf.StartPosition = "CenterParent"
    $sf.FormBorderStyle = "None"
    $sf.BackColor = $colorBg
    $sf.ForeColor = $colorText

    $statusDrag = New-DragHandler $sf

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Location = New-Object System.Drawing.Point(0, 0)
    $bar.Size = New-Object System.Drawing.Size(420, 30)
    $bar.BackColor = $colorPanel
    $bar.Add_MouseDown($statusDrag)
    $sf.Controls.Add($bar)

    $lblBar = New-Object System.Windows.Forms.Label
    $lblBar.Text = "STATUS"
    $lblBar.Font = $fontBtn
    $lblBar.ForeColor = $colorMuted
    $lblBar.Location = New-Object System.Drawing.Point(12, 6)
    $lblBar.Size = New-Object System.Drawing.Size(200, 20)
    $lblBar.Add_MouseDown($statusDrag)
    $bar.Controls.Add($lblBar)

    $btnCloseStatus = New-Object System.Windows.Forms.Button
    $btnCloseStatus.Text = "X"
    $btnCloseStatus.FlatStyle = "Flat"
    $btnCloseStatus.FlatAppearance.BorderSize = 0
    $btnCloseStatus.BackColor = $colorAccent
    $btnCloseStatus.ForeColor = [System.Drawing.Color]::White
    $btnCloseStatus.Size = New-Object System.Drawing.Size(30, 30)
    $btnCloseStatus.Location = New-Object System.Drawing.Point(390, 0)
    $btnCloseStatus.Add_Click({ $sf.Close() })
    $bar.Controls.Add($btnCloseStatus)

    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text = "AJUSTES"
    $lblHeader.Font = $fontBtn
    $lblHeader.ForeColor = $colorAccent
    $lblHeader.Location = New-Object System.Drawing.Point(15, 40)
    $lblHeader.Size = New-Object System.Drawing.Size(300, 20)
    $sf.Controls.Add($lblHeader)

    $y = 66
    foreach ($t in $tweaks) {
        $ativo = [bool](& $t.StatusCheck)

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $t.Label
        $lbl.Font = $fontItem
        $lbl.ForeColor = $colorText
        $lbl.Location = New-Object System.Drawing.Point(15, $y)
        $lbl.Size = New-Object System.Drawing.Size(270, 20)
        $sf.Controls.Add($lbl)

        $tag = New-Object System.Windows.Forms.Label
        $tag.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
        $tag.TextAlign = "MiddleRight"
        $tag.Location = New-Object System.Drawing.Point(290, $y)
        $tag.Size = New-Object System.Drawing.Size(100, 20)
        if ($ativo) {
            $tag.Text = "â— ATIVO"
            $tag.ForeColor = [System.Drawing.Color]::FromArgb(255, 90, 220, 130)
        } else {
            $tag.Text = "â— INATIVO"
            $tag.ForeColor = $colorMuted
        }
        $sf.Controls.Add($tag)

        $y += 24
    }

    $sep = New-Object System.Windows.Forms.Panel
    $sep.BackColor = $colorPanel
    $sep.Location = New-Object System.Drawing.Point(15, ($y + 6))
    $sep.Size = New-Object System.Drawing.Size(375, 1)
    $sf.Controls.Add($sep)
    $y += 22

    $plano          = (powercfg /getactivescheme | Out-String).Trim()
    $achouExe       = if (Test-Path $ValExe) { "encontrado" } else { "nao encontrado" }
    $defenderAtivo  = (Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath -contains $RiotDir
    $defenderStatus = if ($defenderAtivo) { "pasta excluida" } else { "sem exclusao" }
    $atalhoStatus   = if (Test-AtalhoInstalado) { "instalado" } else { "nao instalado" }

    $infoLines = @(
        "Plano de energia: $plano",
        "VALORANT: $achouExe",
        "Defender: $defenderStatus",
        "Atalho sem UAC: $atalhoStatus"
    )
    foreach ($linha in $infoLines) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $linha
        $l.Font = $fontItem
        $l.ForeColor = $colorMuted
        $l.Location = New-Object System.Drawing.Point(15, $y)
        $l.Size = New-Object System.Drawing.Size(375, 20)
        $sf.Controls.Add($l)
        $y += 22
    }

    $sf.ShowDialog($form) | Out-Null
}

# ----------------------- EVENTOS -----------------------

$btnApply.Add_Click({
    $any = $false
    foreach ($t in $tweaks) {
        if ($t.Control.Checked) { & $t.Apply; $any = $true }
    }
    if ($any) {
        [System.Windows.Forms.MessageBox]::Show("Ajustes aplicados. Reinicie o PC pra tudo valer.", "Valorant Otimizador") | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show("Nenhum ajuste selecionado.", "Valorant Otimizador") | Out-Null
    }
})

$btnStatus.Add_Click({
    Show-StatusWindow
})

$btnAtalho.Add_Click({
    if (Test-AtalhoInstalado) {
        $r = [System.Windows.Forms.MessageBox]::Show("Atalho sem UAC ja instalado. Remover?", "Atalho", "YesNo")
        if ($r -eq "Yes") {
            Remove-Atalho
            $btnAtalho.Text = "CRIAR ATALHO"
            [System.Windows.Forms.MessageBox]::Show("Atalho removido.", "Atalho") | Out-Null
        }
    } else {
        $r = [System.Windows.Forms.MessageBox]::Show(
            "Cria um atalho na area de trabalho que abre o painel direto como admin, sem pedir UAC de novo. Criar agora?",
            "Atalho", "YesNo")
        if ($r -eq "Yes") {
            New-Atalho
            $btnAtalho.Text = "REMOVER ATALHO"
            [System.Windows.Forms.MessageBox]::Show("Atalho criado na area de trabalho.", "Atalho") | Out-Null
        }
    }
})

$btnBoost.Add_Click({
    $msgLines = @()
    $proc = Get-Process -Name "VALORANT-Win64-Shipping" -ErrorAction SilentlyContinue
    if ($proc) {
        try { $proc.PriorityClass = "High"; $msgLines += "Prioridade do VALORANT elevada" } catch {}
    } else {
        $msgLines += "VALORANT nao esta rodando agora"
    }

    Save-PowerPlanOriginal
    powercfg /setactive SCHEME_MIN | Out-Null
    $msgLines += "Plano de energia: Alto desempenho"

    $rodando = @()
    foreach ($nome in $BG_HOGS) {
        if (Get-Process -Name $nome -ErrorAction SilentlyContinue) { $rodando += $nome }
    }
    if ($rodando.Count -gt 0) {
        $lista = $rodando -join ", "
        $r = [System.Windows.Forms.MessageBox]::Show("Fechar estes processos? $lista", "Boost agora", "YesNo")
        if ($r -eq "Yes") {
            foreach ($nome in $rodando) { Stop-Process -Name $nome -Force -ErrorAction SilentlyContinue }
            $msgLines += "Processos fechados: $lista"
        }
    }

    ipconfig /flushdns | Out-Null
    $msgLines += "Cache de DNS limpo"
    [System.Windows.Forms.MessageBox]::Show(($msgLines -join "`n"), "Boost agora") | Out-Null
})

$btnRevert.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Sim = restaurar backup exato de antes.`nNao = resetar pro padrao aproximado do Windows.",
        "Reverter", "YesNoCancel")

    if ($r -eq "Yes") {
        if (Test-Path $BackupDir) {
            Get-ChildItem -Path $BackupDir -Filter "*.reg" | ForEach-Object { reg.exe import "$($_.FullName)" *> $null }
            [System.Windows.Forms.MessageBox]::Show("Backup restaurado. Reinicie o PC.", "Reverter") | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("Nenhum backup encontrado.", "Reverter") | Out-Null
        }
    } elseif ($r -eq "No") {
        Set-Reg $GAMECFG_KEY "GameDVR_Enabled" 1
        Remove-Reg $GAMECFG_KEY "GameDVR_FSEBehaviorMode"
        Remove-Reg $GAMECFG_KEY "GameDVR_HonorUserFSEBehaviorMode"
        Remove-Reg $GAMECFG_KEY "GameDVR_DXGIHonorFSEWindowsCompatible"
        Set-Reg $GAMEDVR_KEY "AppCaptureEnabled" 1
        if (Test-Path $ValExe) { Remove-Reg $LAYERS_KEY $ValExe }

        Set-Reg $MMCSS_KEY "NetworkThrottlingIndex" 10
        Set-Reg $MMCSS_KEY "SystemResponsiveness" 20
        Set-Reg $GAMES_KEY "Priority" 2
        Set-Reg $GAMES_KEY "Scheduling Category" "Medium" "String"
        Set-Reg $GAMES_KEY "SFIO Priority" "Normal" "String"

        Remove-Item -Path $IFEO_KEY -Recurse -ErrorAction SilentlyContinue
        Remove-Reg $GFXDRV_KEY "HwSchMode"

        try { Remove-MpPreference -ExclusionPath $RiotDir -ErrorAction Stop } catch {}

        Set-Reg $BGAPPS_KEY "GlobalUserDisabled" 0

        $planoAnterior = Join-Path $BackupDir "power_plan_anterior.txt"
        if (Test-Path $planoAnterior) {
            $guid = (Get-Content $planoAnterior).Trim()
            if ($guid) { powercfg /setactive $guid }
        } else {
            powercfg /setactive SCHEME_BALANCED
        }

        Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
            $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($_.InterfaceGuid)"
            Remove-Reg $ifPath "TcpAckFrequency"
            Remove-Reg $ifPath "TCPNoDelay"
        }

        foreach ($t in $tweaks) { $t.Control.Checked = [bool](& $t.StatusCheck) }
        [System.Windows.Forms.MessageBox]::Show("Resetado pro padrao. Reinicie o PC.", "Reverter") | Out-Null
    }
})

[System.Windows.Forms.Application]::Run($form)
