#Requires AutoHotkey v2.0+
#SingleInstance Force

; Capybara Clicker bot para navegador.
; Uso rapido:
; 1) Abra o jogo e deixe a janela do navegador ativa.
; 2) Passe o mouse sobre a capivara principal e aperte Ctrl+Alt+C.
; 3) Passe o mouse sobre os slots de upgrade e aperte Ctrl+Alt+1..6.
; 4) Aperte F8 para ligar/pausar o bot.
; 5) Aperte F9 para ver o status.
;
; O script usa ControlClick em coordenadas relativas da janela,
; entao ele nao move o seu mouse e deixa voce clicar tambem.
; Se voce mudar muito o zoom ou o layout da pagina, recapture os pontos.

global configPath := A_ScriptDir "\capybara_clicker_bot.ini"
global clickIntervalMs := 25
global upgradeIntervalMs := 350
global isRunning := false
global targetHwnd := 0
global capybaraPoint := 0
global upgradePoints := []
global nextUpgradeIndex := 1

SetControlDelay(-1)
LoadConfig()
ShowTip("Bot carregado. Ctrl+Alt+C captura a capivara. F8 liga ou pausa.", 2500)

F8::ToggleBot()
F9::ShowStatus()
^!c::CaptureCapybara()
^!1::CaptureUpgrade(1)
^!2::CaptureUpgrade(2)
^!3::CaptureUpgrade(3)
^!4::CaptureUpgrade(4)
^!5::CaptureUpgrade(5)
^!6::CaptureUpgrade(6)
^!r::ClearUpgrades()

ToggleBot() {
    global isRunning, targetHwnd, capybaraPoint, clickIntervalMs, upgradeIntervalMs, nextUpgradeIndex

    if isRunning {
        StopBot()
        return
    }

    if !capybaraPoint {
        ShowTip("Capture a capivara com Ctrl+Alt+C antes de ligar o bot.")
        return
    }

    targetHwnd := WinGetID("A")
    if !targetHwnd {
        ShowTip("Nao achei uma janela ativa. Deixe o navegador em foco.")
        return
    }

    if !GetClientSize(targetHwnd, &clientW, &clientH) {
        ShowTip("Nao consegui ler a janela ativa.")
        return
    }

    if (clientW <= 0 || clientH <= 0) {
        ShowTip("A janela ativa nao parece valida para calibracao.")
        return
    }

    isRunning := true
    nextUpgradeIndex := 1
    SetTimer(AutoClickTick, clickIntervalMs)
    SetTimer(UpgradeTick, upgradeIntervalMs)
    ShowTip("Bot ligado. F8 pausa. F9 mostra status.")
}

StopBot() {
    global isRunning

    if !isRunning {
        return
    }

    isRunning := false
    SetTimer(AutoClickTick, 0)
    SetTimer(UpgradeTick, 0)
    ShowTip("Bot pausado.")
}

AutoClickTick(*) {
    global isRunning, capybaraPoint

    if !isRunning || !capybaraPoint {
        return
    }

    ClickPoint(capybaraPoint)
}

UpgradeTick(*) {
    global isRunning, upgradePoints, nextUpgradeIndex

    if !isRunning || upgradePoints.Length = 0 {
        return
    }

    attempts := 0
    while (attempts < upgradePoints.Length) {
        if (nextUpgradeIndex > upgradePoints.Length) {
            nextUpgradeIndex := 1
        }

        point := upgradePoints[nextUpgradeIndex]
        nextUpgradeIndex += 1
        attempts += 1

        if point {
            ClickPoint(point)
            break
        }
    }
}

CaptureCapybara() {
    global capybaraPoint

    point := CaptureCurrentMousePoint()
    if !point {
        return
    }

    capybaraPoint := point
    SaveConfig()
    ShowTip("Ponto principal salvo.")
}

CaptureUpgrade(slot) {
    global upgradePoints

    point := CaptureCurrentMousePoint()
    if !point {
        return
    }

    while (upgradePoints.Length < slot) {
        upgradePoints.Push(0)
    }

    upgradePoints[slot] := point
    SaveConfig()
    ShowTip("Upgrade " slot " salvo.")
}

ClearUpgrades() {
    global upgradePoints, nextUpgradeIndex

    upgradePoints := []
    nextUpgradeIndex := 1
    SaveConfig()
    ShowTip("Lista de upgrades limpa.")
}

CaptureCurrentMousePoint() {
    global targetHwnd

    hwnd := WinGetID("A")
    if !hwnd {
        ShowTip("Deixe o navegador do jogo ativo antes de capturar.")
        return 0
    }

    if !GetClientSize(hwnd, &clientW, &clientH) {
        ShowTip("Nao consegui ler o tamanho da janela ativa.")
        return 0
    }

    MouseGetPos(&relX, &relY)

    if (relX < 0 || relY < 0 || relX > clientW || relY > clientH) {
        ShowTip("Passe o mouse por cima do jogo antes de capturar.")
        return 0
    }

    targetHwnd := hwnd
    return {
        x: relX / clientW,
        y: relY / clientH
    }
}

ClickPoint(point) {
    global targetHwnd

    if !point || !targetHwnd {
        return false
    }

    if !WinExist("ahk_id " targetHwnd) {
        StopBot()
        ShowTip("A janela alvo nao existe mais. Ative o navegador e aperte F8.")
        return false
    }

    if !GetClientSize(targetHwnd, &clientW, &clientH) {
        return false
    }

    x := Round(Max(5, Min(clientW - 5, point.x * clientW)))
    y := Round(Max(5, Min(clientH - 5, point.y * clientH)))

    try {
        ControlClick("X" x " Y" y, "ahk_id " targetHwnd, , "Left", 1, "NA Pos")
        return true
    } catch {
        return false
    }
}

GetClientSize(hwnd, &clientW, &clientH) {
    clientX := 0
    clientY := 0
    clientW := 0
    clientH := 0

    try {
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)
        return true
    } catch {
        return false
    }
}

ShowStatus() {
    global isRunning, capybaraPoint, upgradePoints, clickIntervalMs, upgradeIntervalMs, targetHwnd

    upgradeCount := 0
    for _, point in upgradePoints {
        if point {
            upgradeCount += 1
        }
    }

    statusText := "Estado: " (isRunning ? "ligado" : "pausado")
    statusText .= "`nCapivara salva: " (capybaraPoint ? "sim" : "nao")
    statusText .= "`nUpgrades salvos: " upgradeCount
    statusText .= "`nJanela vinculada: " (targetHwnd ? "sim" : "nao")
    statusText .= "`nClickIntervalMs: " clickIntervalMs
    statusText .= "`nUpgradeIntervalMs: " upgradeIntervalMs
    statusText .= "`nCtrl+Alt+C capivara | Ctrl+Alt+1..6 upgrades | Ctrl+Alt+R limpa"
    ShowTip(statusText, 3500)
}

ShowTip(text, durationMs := 1500) {
    ToolTip(text)
    SetTimer(ClearTip, -durationMs)
}

ClearTip() {
    ToolTip()
}

LoadConfig() {
    global configPath, clickIntervalMs, upgradeIntervalMs, capybaraPoint, upgradePoints

    if !FileExist(configPath) {
        return
    }

    clickIntervalMs := Max(10, Round(IniRead(configPath, "Timings", "ClickIntervalMs", clickIntervalMs) + 0))
    upgradeIntervalMs := Max(100, Round(IniRead(configPath, "Timings", "UpgradeIntervalMs", upgradeIntervalMs) + 0))

    capybaraText := IniRead(configPath, "Points", "Capybara", "")
    capybaraPoint := ParsePoint(capybaraText)

    upgradesText := IniRead(configPath, "Points", "Upgrades", "")
    upgradePoints := []

    if (upgradesText = "") {
        return
    }

    for _, rawPoint in StrSplit(upgradesText, "|") {
        parsedPoint := ParsePoint(rawPoint)
        upgradePoints.Push(parsedPoint)
    }
}

SaveConfig() {
    global configPath, clickIntervalMs, upgradeIntervalMs, capybaraPoint, upgradePoints

    IniWrite(clickIntervalMs, configPath, "Timings", "ClickIntervalMs")
    IniWrite(upgradeIntervalMs, configPath, "Timings", "UpgradeIntervalMs")
    IniWrite(PointToText(capybaraPoint), configPath, "Points", "Capybara")
    IniWrite(UpgradeListToText(), configPath, "Points", "Upgrades")
}

PointToText(point) {
    if !point {
        return ""
    }

    return Format("{:0.6f},{:0.6f}", point.x, point.y)
}

UpgradeListToText() {
    global upgradePoints

    parts := []
    for _, point in upgradePoints {
        parts.Push(PointToText(point))
    }
    return JoinParts(parts, "|")
}

JoinParts(parts, separator) {
    joined := ""

    for index, part in parts {
        if (index > 1) {
            joined .= separator
        }
        joined .= part
    }

    return joined
}

ParsePoint(text) {
    text := Trim(text)
    if (text = "") {
        return 0
    }

    parts := StrSplit(text, ",")
    if (parts.Length != 2) {
        return 0
    }

    x := Trim(parts[1]) + 0
    y := Trim(parts[2]) + 0

    if (x < 0 || x > 1 || y < 0 || y > 1) {
        return 0
    }

    return {
        x: x,
        y: y
    }
}
