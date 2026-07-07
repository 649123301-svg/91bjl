#Requires AutoHotkey v2.0
#Warn All, Off

; ============================================================
; ★★★ 自动请求管理员权限 ★★★
; ============================================================
if !A_IsAdmin {
    try {
        Run "*RunAs " . A_ScriptFullPath
        ExitApp()
    } catch {
        MsgBox "此脚本需要管理员权限才能运行！`n`n请右键点击脚本，选择「以管理员身份运行」。", "权限不足", "Icon!"
        ExitApp()
    }
}

; ============================================================
; ★★★ 坐标模式和窗口进程配置 ★★★
; ============================================================
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

WinProcess := "雷电模拟器"

; ============================================================
; ★★★ 日志系统配置（启动时自动清空） ★★★
; ============================================================
global LogFile := ""
global LogEnabled := true
global LogLevel := 2
global LogContent := ""
global LogGui := ""
global LogEditCtrl := ""
global LogUpdateTimer := 0
global ScriptVersion := "v1.4.2"
global g_Initialized := false
global g_InitConfirmed := false

; ★★★ 在线更新配置 ★★★
global VersionFile := "version.txt"

; ★★★ OCR相关配置 ★★★
global OcrPythonPath := "py -3.11"
global OcrPythonPath := ""
global OcrScriptPath := ""
global OcrWorkingDir := "C:\Users\Administrator\Desktop\MyScripts"
global BetAmountResultFile := "C:\Users\Administrator\Desktop\zhuajiang\bet_amount_result.txt"
global initBalanceEdit := "" 
global btnBalance := ""
global IsBalanceSet := false  ; ★★★ 本金按钮是否已点击 ★★★
global chkBalance := ""
global btnBetToggle := ""
global statusText := ""
global stopProfitEdit := ""
global stopLossEdit := ""
global btnGrabToggle := ""
global OriginalBalance := 0      ; ★★★ 原始本金 ★★★
global LastBalanceReadSec := -1  ; ★★★ 记录上次读取余额的秒数 ★★★
global LastBetTriggerSec := -1  ; ★★★ 记录上次下注触发的秒数 ★★★
global IsBalanceFirstTime := true ; ★★★ 是否第一次勾选本金 ★★★
global IsBetting := false  ; ★★★ 是否正在下注 ★★★
global betDelayEdit := ""
global clickDelayEdit := ""

; ★★★ 云端延迟参数 ★★★
global CloudBetDelay := 2000
global CloudClickDelay := 500
; ★★★ 全局延迟配置 ★★★
global GlobalConfig := Map()
GlobalConfig["bet_delay"] := 2000
GlobalConfig["click_delay"] := 500

; ★★★ 启动时清空logs文件夹 ★★★
ClearLogsFolder() {
    logDir := A_ScriptDir . "\logs"
    if DirExist(logDir) {
        try {
            Loop Files, logDir . "\*.*", "F" {
                try FileDelete(A_LoopFileFullPath)
            }
            WriteLog("🧹 已清空旧日志文件", 2)
        } catch {
        }
    }
}

InitLog() {
    global LogFile, LogContent, ScriptVersion
    logDir := "C:\Users\Administrator\Desktop\zhuajiang\logs"
    if !DirExist(logDir) {
        DirCreate(logDir)
    }
    
    ; ★★★ 删除所有旧日志（只保留最新一个） ★★★
    Loop Files, logDir . "\*.txt", "F" {
        try {
            FileDelete(A_LoopFileFullPath)
            WriteLog("🗑️ 已删除旧日志: " . A_LoopFileName, 2)
        } catch {
        }
    }
    
    timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    LogFile := logDir . "\script_log_" . timestamp . ".txt"
    LogContent := ""
    WriteLog("=== 脚本启动 ===", 2)
    WriteLog("脚本版本: " . ScriptVersion, 2)
    WriteLog("管理员权限: " . (A_IsAdmin ? "✅ 是" : "❌ 否"), 2)
    WriteLog("机器指纹: " . GetMachineID(), 2)
    
    InitEmulatorPosition()
}

WriteLog(message, level := 2) {
    global LogFile, LogEnabled, LogLevel, LogContent, LogEditCtrl, LogGui
    if !LogEnabled || level > LogLevel {
        return
    }
    try {
        levelNames := Map()
        levelNames[0] := "[错误]"
        levelNames[1] := "[警告]"
        levelNames[2] := "[信息]"
        levelNames[3] := "[调试]"
        
        timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        logLine := timestamp . " " . (levelNames.Has(level) ? levelNames[level] : "[信息]") . " " . message
        
        LogContent .= logLine . "`n"

        ; ★★★ 限制 LogContent 行数，只保留最近 500 行 ★★★
        lines := StrSplit(LogContent, "`n")
        if lines.Length > 500 {
            newContent := ""
            startIdx := lines.Length - 500 + 1
            Loop 500 {
                idx := startIdx + A_Index - 1
                if idx <= lines.Length {
                    newContent .= lines[idx] . "`n"
                }
            }
            LogContent := newContent
        }
        
        file := FileOpen(LogFile, "a", "UTF-8")
        if IsObject(file) {
            file.Write(logLine . "`n")
            file.Close()
        }
        
        UpdateLogWindow()
    } catch {
    }
}

UpdateLogWindow() {
    global LogContent, LogEditCtrl, LogGui
    
    if LogGui != "" && IsObject(LogGui) {
        try {
            if LogEditCtrl != "" && IsObject(LogEditCtrl) {
                LogEditCtrl.Value := LogContent
                SendMessage(0x115, 7, 0, LogEditCtrl)
            }
        } catch {
        }
    }
}

; ============================================================
; ★★★ 关闭日志窗口 ★★★
; ============================================================
CloseLogWindow(*) {
    global LogGui, LogEditCtrl
    try {
        if LogGui != "" && IsObject(LogGui) {
            LogGui.Destroy()
        }
    } catch {
    }
    LogGui := ""
    LogEditCtrl := ""
}

; ============================================================
; ★★★ 显示日志窗口 ★★★
; ============================================================
ShowLogWindow() {
    global LogContent, LogGui, LogEditCtrl, LogUpdateTimer
    
    if LogContent == "" {
        CustomMsgBox("日志", "暂无日志记录")
        return
    }
    
    if LogGui != "" && IsObject(LogGui) {
        try {
            LogGui.Show()
            LogGui.Focus()
            return
        } catch {
            LogGui := ""
            LogEditCtrl := ""
        }
    }
    
    try {
        LogGui := Gui("+OwnDialogs -SysMenu +Resize")
        LogGui.Title := "📋 运行日志"
        LogGui.SetFont("s9", "Consolas")
        
        width := 700
        height := 450
        
        maxLineLen := 0
        lines := StrSplit(LogContent, "`n")
        for line in lines {
            len := 0
            loop parse line {
                if Ord(A_LoopField) > 127 {
                    len += 2
                } else {
                    len += 1
                }
            }
            if len > maxLineLen {
                maxLineLen := len
            }
        }
        idealWidth := maxLineLen * 8 + 40
        if idealWidth > width {
            width := idealWidth
        }
        if width > 1200 {
            width := 1200
        }
        if width < 600 {
            width := 600
        }
        
        LogEditCtrl := LogGui.Add("Edit", 
            "x10 y10 w" . (width - 30) . " h" . (height - 70) . 
            " ReadOnly +VScroll +HScroll", 
            LogContent)
        
        if !IsObject(LogEditCtrl) {
            CustomMsgBox("日志", "创建日志窗口失败！")
            return
        }
        
        LogEditCtrl.SetFont("s9", "Consolas")
        
        LogEditCtrl.Value := LogContent
        SendMessage(0x115, 7, 0, LogEditCtrl)
        SendMessage(0xB1, -1, -1, LogEditCtrl)
        
        btnClose := LogGui.Add("Button", 
            "x" . (width - 120) . " y" . (height - 50) . " w100 h35 Default", 
            "关闭")
        btnClose.OnEvent("Click", CloseLogWindow)
        
        LogGui.OnEvent("Close", CloseLogWindow)
        LogGui.OnEvent("Escape", CloseLogWindow)
        
        LogGui.Show("w" . width . " h" . height)
        
        btnClose.Focus()
        
    } catch as err {
        CustomMsgBox("日志错误", "打开日志窗口失败！`n`n" . err.Message)
        LogGui := ""
        LogEditCtrl := ""
    }
}

; ============================================================
; ★★★ 自定义消息框 ★★★
; ============================================================
CustomMsgBox(title, message, buttons := "OK") {
    if (buttons = "YesNo") {
        result := MsgBox(message, title, "YesNo")
        if (result = 6) {
            return "Yes"
        } else {
            return "No"
        }
    } else {
        MsgBox(message, title)
        return "OK"
    }
}

; ============================================================
; ★★★ JSONBin 卡密验证配置 ★★★
; ============================================================
global JSONBIN_BIN_ID := "6a4002fdf5f4af5e2939b0c0"
global JSONBIN_API_KEY := "$2a$10$QA1Lh48DnnzXWbzqm87lXOmPBuYLuvIHVocSJiqo51NEFjqX/AaNO"
global JSONBIN_URL := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID . "/latest"

global StopBetting := false
global ScriptPaused := false
global IsAuthorized := false
global GuiMain := ""
global CurrentUserKey := ""
global UserInfo := Map()
global CARDS_DATA := Map()
global SettingsGui := ""

; ★★★ 抓奖功能相关变量 ★★★
global IsGrabEnabled := false
global BJLDetected := false
global BJLEnterDetected := false
global GrabLastRunSec := -1

; ★★★ 抓奖坐标配置 ★★★
global GrabPos := Map()
GrabPos["exit"] := [0.1222, 0.2570]
GrabPos["confirm"] := [0.5944, 0.6392]
GrabPos["enter"] := [0.7476, 0.3772]

; ★★★ 动态图标位置 ★★★
global EnterIconX := ""
global EnterIconY := ""

; ★★★ 重复下注检测变量 ★★★
global LastJTime := ""
global SameTimeCount := 0
global MaxSameTimeCount := 2

; ★★★ 卡密输入掩码相关变量 ★★★
global g_ActualKey := ""
global g_KeyInput := ""

; ============================================================
; ★★★ 按钮相对坐标配置 ★★★
; ============================================================
global ButtonPos := Map()
ButtonPos["zhuang"] := [0.6900, 0.5231]
ButtonPos["xian"] := [0.3925, 0.4545]
ButtonPos["amount"] := [0.4425, 0.8689]
ButtonPos["confirm"] := [0.7675, 0.8674]

; ★★★ UserConfig ★★★
global UserConfig := Map()
UserConfig["InitBalance"] := 0
UserConfig["StopProfit"] := 0
UserConfig["StopLoss"] := 0
UserConfig["BetDelay"] := 2000
UserConfig["ClickDelay"] := 500

; ============================================================
; ★★★ 获取模拟器窗口位置 ★★★
; ============================================================
GetEmulatorRect() {
    global WinProcess, EmulatorRect
    rect := Map()
    rect["left"] := 0
    rect["top"] := 0
    rect["right"] := 0
    rect["bottom"] := 0
    rect["width"] := 0
    rect["height"] := 0
    rect["hwnd"] := 0
    
    try {
        hwnd := WinExist(WinProcess)
        if hwnd {
            WinGetPos(&x, &y, &w, &h, hwnd)
            rect["left"] := x
            rect["top"] := y
            rect["right"] := x + w
            rect["bottom"] := y + h
            rect["width"] := w
            rect["height"] := h
            rect["hwnd"] := hwnd
            EmulatorRect := rect
            WriteLog("📐 窗口坐标: (" . x . "," . y . ") 大小: " . w . "x" . h, 3)
        } else {
            WriteLog("⚠️ 未找到模拟器窗口: " . WinProcess, 1)
        }
    } catch as err {
        WriteLog("⚠️ 获取模拟器窗口失败: " . err.Message, 1)
    }
    return rect
}

InitEmulatorPosition() {
    WriteLog("🔍 初始化模拟器窗口位置...", 2)
    if !WinExist(WinProcess) {
        WriteLog("⚠️ 未找到模拟器窗口，请先打开模拟器", 1)
        return false
    }
    rect := GetEmulatorRect()
    if rect["width"] > 0 && rect["height"] > 0 {
        WriteLog("✅ 模拟器窗口: " . rect["left"] . "," . rect["top"] . " " . rect["width"] . "x" . rect["height"], 2)
        return true
    }
    return false
}

ResetEmulatorPosition() {
    global EmulatorRect
    WriteLog("🔄 重新获取模拟器窗口位置...", 2)
    rect := GetEmulatorRect()
    if rect["width"] > 0 && rect["height"] > 0 {
        WriteLog("✅ 重新获取成功: " . rect["left"] . "," . rect["top"] . " " . rect["width"] . "x" . rect["height"], 2)
        return true
    }
    return false
}

ClickRelative(relX, relY, desc := "") {
    rect := GetEmulatorRect()
    if rect["width"] == 0 || rect["height"] == 0 {
        WriteLog("❌ 无法获取模拟器窗口坐标", 0)
        return false
    }
    screenX := Round(rect["left"] + (rect["width"] * relX))
    screenY := Round(rect["top"] + (rect["height"] * relY))
    if (desc != "") {
        WriteLog("🖱️ " . desc . " → (" . screenX . "," . screenY . ")", 3)
    }
    Click screenX, screenY
    return true
}

PixelGetColorRelative(relX, relY) {
    rect := GetEmulatorRect()
    if rect["width"] == 0 || rect["height"] == 0 {
        return 0
    }
    screenX := Round(rect["left"] + (rect["width"] * relX))
    screenY := Round(rect["top"] + (rect["height"] * relY))
    try {
        PixelGetColor(&color, screenX, screenY)
        return color
    } catch {
        return 0
    }
}

; ============================================================
; ★★★ 调试热键 ★★★
; ============================================================
F3:: {
    if !WinExist(WinProcess) {
        ToolTip "请先激活模拟器窗口"
        SetTimer(ToolTipClear, -2000)
        return
    }
    MouseGetPos(&mx, &my)
    rect := GetEmulatorRect()
    if rect["width"] == 0 {
        ToolTip "无法获取窗口信息"
        SetTimer(ToolTipClear, -2000)
        return
    }
    relX := Round((mx - rect["left"]) / rect["width"], 4)
    relY := Round((my - rect["top"]) / rect["height"], 4)
    result := "相对坐标: " . relX . ", " . relY . "`n屏幕坐标: " . mx . ", " . my
    A_Clipboard := "[" . relX . ", " . relY . "]"
    ToolTip result
    SetTimer(ToolTipClear, -5000)
    MsgBox result "`n`n✅ 已复制到剪贴板: [" . relX . ", " . relY . "]"
}

F4:: {
    ResetEmulatorPosition()
    ToolTip "✅ 已重新获取窗口位置"
    SetTimer(ToolTipClear, -2000)
}

; ============================================================
; ★★★ 纯 AHK 哈希 ★★★
; ============================================================
GetFingerprint(str) {
    h1 := 0x811C9DC5
    h2 := 0x811C9DC5
    h3 := 0x811C9DC5
    h4 := 0x811C9DC5
    i := 0
    loop parse str {
        i++
        c := Ord(A_LoopField)
        h1 := ((h1 ^ c) * 0x01000193) & 0xFFFFFFFF
        h2 := ((h2 ^ c) * 0x01000193) & 0xFFFFFFFF
        h3 := ((h3 ^ c) * 0x01000193) & 0xFFFFFFFF
        h4 := ((h4 ^ c) * 0x01000193) & 0xFFFFFFFF
        h1 := ((h1 ^ (i & 0xFF)) * 0x01000193) & 0xFFFFFFFF
        h2 := ((h2 ^ ((i >> 8) & 0xFF)) * 0x01000193) & 0xFFFFFFFF
        h3 := ((h3 ^ ((i >> 16) & 0xFF)) * 0x01000193) & 0xFFFFFFFF
        h4 := ((h4 ^ ((i >> 24) & 0xFF)) * 0x01000193) & 0xFFFFFFFF
    }
    h1 := (h1 ^ (h1 >> 16)) & 0xFFFFFFFF
    h2 := (h2 ^ (h2 >> 16)) & 0xFFFFFFFF
    h3 := (h3 ^ (h3 >> 16)) & 0xFFFFFFFF
    h4 := (h4 ^ (h4 >> 16)) & 0xFFFFFFFF
    h1 := (h1 ^ (h1 << 13)) & 0xFFFFFFFF
    h2 := (h2 ^ (h2 << 13)) & 0xFFFFFFFF
    h3 := (h3 ^ (h3 << 13)) & 0xFFFFFFFF
    h4 := (h4 ^ (h4 << 13)) & 0xFFFFFFFF
    return Format("{:08x}{:08x}{:08x}{:08x}", h1, h2, h3, h4)
}

; ============================================================
; ★★★ 硬件指纹 ★★★
; ============================================================
GetHardwareInfo() {
    info := Map()
    info["cpu"] := ""
    info["motherboard"] := ""
    info["bios"] := ""
    info["disk"] := ""
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Processor") {
            if item.ProcessorId != "" {
                cpuID := Trim(item.ProcessorId)
                if (StrLen(cpuID) >= 4) {
                    info["cpu"] := cpuID
                    break
                }
            }
        }
    } catch {
    }
    if (info["cpu"] == "") {
        try {
            for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Processor") {
                if item.Name != "" {
                    cpuName := RegExReplace(Trim(item.Name), "[^a-zA-Z0-9]", "")
                    if (cpuName != "") {
                        info["cpu"] := "CPU_" . cpuName . "_" . item.NumberOfCores
                        break
                    }
                }
            }
        } catch {
        }
    }
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_BaseBoard") {
            if item.SerialNumber != "" && item.SerialNumber != "To be filled by O.E.M." && item.SerialNumber != "Default string" {
                info["motherboard"] := Trim(item.SerialNumber)
                break
            }
        }
    } catch {
    }
    if (info["motherboard"] == "") {
        try {
            for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_BaseBoard") {
                if item.Product != "" && item.Manufacturer != "" {
                    product := RegExReplace(Trim(item.Product), "[^a-zA-Z0-9]", "")
                    manufacturer := RegExReplace(Trim(item.Manufacturer), "[^a-zA-Z0-9]", "")
                    if (product != "" && manufacturer != "") {
                        info["motherboard"] := "MB_" . manufacturer . "_" . product
                        break
                    }
                }
            }
        } catch {
        }
    }
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_ComputerSystemProduct") {
            if item.UUID != "" && item.UUID != "00000000-0000-0000-0000-000000000000" {
                info["bios"] := Trim(item.UUID)
                break
            }
        }
    } catch {
    }
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_PhysicalMedia") {
            if item.SerialNumber != "" {
                serial := RegExReplace(item.SerialNumber, "[^a-zA-Z0-9]", "")
                if (StrLen(serial) >= 4) {
                    info["disk"] := serial
                    break
                }
            }
        }
    } catch {
    }
    if (info["disk"] == "") {
        try {
            for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_DiskDrive") {
                if item.Model != "" && !InStr(item.Model, "Virtual") && !InStr(item.Model, "VMware") {
                    model := RegExReplace(Trim(item.Model), "[^a-zA-Z0-9]", "")
                    if (model != "") {
                        info["disk"] := "DISK_" . model
                        break
                    }
                }
            }
        } catch {
        }
    }
    if (info["disk"] == "") {
        info["disk"] := "DISK_UNKNOWN"
    }
    return info
}

; ============================================================
; ★★★ 机器指纹管理系统 ★★★
; ============================================================
global FINGERPRINT_REG_PATH := "HKEY_CURRENT_USER\Software\WinBetScript"
global FINGERPRINT_REG_KEY := "MachineID"
global FINGERPRINT_CACHE_FILE := "C:\Users\Administrator\Desktop\zhuajiang\machine_id.dat"
global FINGERPRINT_BACKUP_FILE := "C:\Users\Administrator\Desktop\zhuajiang\machine_id.bak"

; ============================================================
; ★★★ 主入口：获取机器指纹 ★★★
; ============================================================
GetMachineID() {
    regID := ReadFingerprintFromRegistry()
    if (regID != "") {
        WriteLog("📌 从注册表读取指纹: " . MaskFingerprint(regID), 3)
        if IsValidFingerprint(regID) {
            SyncFingerprintToCache(regID)
            return regID
        }
    }
    
    cacheID := ReadFingerprintFromCache()
    if (cacheID != "" && IsValidFingerprint(cacheID)) {
        WriteLog("📌 从缓存文件读取指纹: " . MaskFingerprint(cacheID), 3)
        SyncFingerprintToRegistry(cacheID)
        return cacheID
    }
    
    backupID := ReadFingerprintFromBackup()
    if (backupID != "" && IsValidFingerprint(backupID)) {
        WriteLog("📌 从备份文件恢复指纹: " . MaskFingerprint(backupID), 2)
        SaveFingerprintToAll(backupID)
        return backupID
    }
    
    WriteLog("🆕 未找到有效指纹，生成新指纹", 2)
    newID := GenerateStableFingerprint()
    SaveFingerprintToAll(newID)
    WriteLog("✅ 新指纹生成成功: " . MaskFingerprint(newID), 2)
    return newID
}

; ============================================================
; ★★★ 指纹一致性检查和修复 ★★★
; ============================================================
CheckFingerprintConsistency() {
    WriteLog("🔍 开始检查机器指纹一致性...", 2)
    
    regID := ReadFingerprintFromRegistry()
    cacheID := ReadFingerprintFromCache()
    backupID := ReadFingerprintFromBackup()
    
    if (regID != "" && cacheID != "" && backupID != "" && 
        regID == cacheID && cacheID == backupID && 
        IsValidFingerprint(regID)) {
        WriteLog("✅ 所有指纹一致，状态完美", 2)
        return regID
    }
    
    if (regID != "" && cacheID != "" && regID != cacheID && 
        IsValidFingerprint(regID)) {
        WriteLog("⚠️ 注册表与缓存不一致，以注册表为准", 1)
        SyncFingerprintToCache(regID)
        SyncFingerprintToBackup(regID)
        WriteLog("✅ 已同步到缓存和备份", 2)
        return regID
    }
    
    if (regID != "" && IsValidFingerprint(regID) && 
        (cacheID == "" || !IsValidFingerprint(cacheID))) {
        WriteLog("📌 注册表有效，同步到缓存和备份", 2)
        SyncFingerprintToCache(regID)
        SyncFingerprintToBackup(regID)
        return regID
    }
    
    if (cacheID != "" && IsValidFingerprint(cacheID) && 
        (regID == "" || !IsValidFingerprint(regID))) {
        WriteLog("📌 缓存有效，同步到注册表和备份", 2)
        SyncFingerprintToRegistry(cacheID)
        SyncFingerprintToBackup(cacheID)
        return cacheID
    }
    
    if (backupID != "" && IsValidFingerprint(backupID) && 
        (regID == "" || !IsValidFingerprint(regID)) && 
        (cacheID == "" || !IsValidFingerprint(cacheID))) {
        WriteLog("📌 从备份恢复指纹", 2)
        SaveFingerprintToAll(backupID)
        return backupID
    }
    
    WriteLog("⚠️ 所有指纹都无效，生成新指纹", 1)
    newID := GenerateStableFingerprint()
    SaveFingerprintToAll(newID)
    WriteLog("✅ 新指纹已保存到所有位置", 2)
    return newID
}

; ============================================================
; ★★★ 读写函数 ★★★
; ============================================================
ReadFingerprintFromRegistry() {
    try {
        RegRead(&value, FINGERPRINT_REG_PATH, FINGERPRINT_REG_KEY)
        return Trim(value)
    } catch {
        return ""
    }
}

ReadFingerprintFromCache() {
    cacheFile := FINGERPRINT_CACHE_FILE
    if !FileExist(cacheFile) {
        return ""
    }
    try {
        file := FileOpen(cacheFile, "r", "UTF-8")
        if IsObject(file) {
            content := Trim(file.Read())
            file.Close()
            return content
        }
    } catch {
    }
    return ""
}

ReadFingerprintFromBackup() {
    backupFile := FINGERPRINT_BACKUP_FILE
    if !FileExist(backupFile) {
        return ""
    }
    try {
        file := FileOpen(backupFile, "r", "UTF-8")
        if IsObject(file) {
            content := Trim(file.Read())
            file.Close()
            return content
        }
    } catch {
    }
    return ""
}

SyncFingerprintToRegistry(id) {
    try {
        RegWrite(id, "REG_SZ", FINGERPRINT_REG_PATH, FINGERPRINT_REG_KEY)
        WriteLog("💾 指纹已同步到注册表", 3)
        return true
    } catch {
        WriteLog("❌ 同步到注册表失败", 1)
        return false
    }
}

SyncFingerprintToCache(id) {
    cacheFile := FINGERPRINT_CACHE_FILE
    try {
        file := FileOpen(cacheFile, "w", "UTF-8")
        if IsObject(file) {
            file.Write(id)
            file.Close()
            WriteLog("💾 指纹已同步到缓存文件", 3)
            return true
        }
    } catch {
    }
    WriteLog("❌ 同步到缓存文件失败", 1)
    return false
}

SyncFingerprintToBackup(id) {
    backupFile := FINGERPRINT_BACKUP_FILE
    try {
        file := FileOpen(backupFile, "w", "UTF-8")
        if IsObject(file) {
            file.Write(id)
            file.Close()
            WriteLog("💾 指纹已同步到备份文件", 3)
            return true
        }
    } catch {
    }
    WriteLog("❌ 同步到备份文件失败", 1)
    return false
}

SaveFingerprintToAll(id) {
    SyncFingerprintToRegistry(id)
    SyncFingerprintToCache(id)
    SyncFingerprintToBackup(id)
}

IsValidFingerprint(id) {
    if (id == "" || StrLen(id) < 32) {
        return false
    }
    if !RegExMatch(id, "^[0-9a-fA-F]{32,}$") {
        return false
    }
    return true
}

MaskFingerprint(id) {
    if (StrLen(id) <= 8) {
        return "****"
    }
    return SubStr(id, 1, 8) . "****" . SubStr(id, -4)
}

; ============================================================
; ★★★ 生成稳定的指纹 ★★★
; ============================================================
GenerateStableFingerprint() {
    parts := []
    
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Processor") {
            if item.ProcessorId != "" {
                cpuID := Trim(item.ProcessorId)
                if (StrLen(cpuID) >= 4) {
                    parts.Push("CPU_" . cpuID)
                    break
                }
            }
        }
    } catch {
    }
    
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_BaseBoard") {
            if item.SerialNumber != "" && item.SerialNumber != "To be filled by O.E.M." && item.SerialNumber != "Default string" {
                parts.Push("MB_" . Trim(item.SerialNumber))
                break
            }
        }
    } catch {
    }
    
    try {
        for item in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_ComputerSystemProduct") {
            if item.UUID != "" && item.UUID != "00000000-0000-0000-0000-000000000000" {
                parts.Push("UUID_" . Trim(item.UUID))
                break
            }
        }
    } catch {
    }
    
    try {
        RegRead(&installDate, "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "InstallDate")
        if (installDate != "") {
            parts.Push("INST_" . installDate)
        }
    } catch {
    }
    
    try {
        RegRead(&productId, "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "ProductId")
        if (productId != "" && productId != "00000-00000-00000-00000") {
            parts.Push("PID_" . RegExReplace(productId, "-", ""))
        }
    } catch {
    }
    
    combined := ""
    for part in parts {
        if (combined != "") {
            combined .= "|" . part
        } else {
            combined .= part
        }
    }
    
    if (combined == "") {
        try {
            RegRead(&installDate, "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "InstallDate")
            combined := "FALLBACK_" . installDate . "_" . A_ComputerName
        } catch {
            combined := "FALLBACK_" . A_ComputerName . "_" . A_TickCount
        }
    }
    
    return GetFingerprint(combined)
}

; ============================================================
; ★★★ HTTP 请求函数（使用 WinHttp，稳定版本） ★★★
; ============================================================
HttpRequest(url, headers, method := "GET", data := "") {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open(method, url, false)
        http.SetRequestHeader("Content-Type", "application/json")
        if IsObject(headers) {
            for key, value in headers {
                http.SetRequestHeader(key, value)
            }
        }
        if (data != "") {
            http.Send(data)
        } else {
            http.Send()
        }
        http.WaitForResponse()
        if http.Status = 200 {
            return http.ResponseText
        }
        WriteLog("❌ HTTP 状态码: " . http.Status, 1)
        return ""
    } catch as e {
        WriteLog("❌ HTTP 请求异常: " . e.Message, 1)
        return ""
    }
}

; ============================================================
; ★★★ 读取 JSONBin 卡密数据 ★★★
; ============================================================
ReadCardsFromJSONBin() {
    global JSONBIN_URL, JSONBIN_API_KEY, GlobalConfig
    headers := Map()
    headers["X-Master-Key"] := JSONBIN_API_KEY
    response := HttpRequest(JSONBIN_URL, headers)
    if (response == "") {
        return Map()
    }
    try {
        result := ParseFullJSONBinResponse(response)
        if result.Has("cards") {
            if result.Has("global_config") {
                GlobalConfig := result["global_config"]
                WriteLog("📥 读取全局配置: 下注=" . GlobalConfig["bet_delay"] . ", 点击=" . GlobalConfig["click_delay"], 2)
            }
            return result["cards"]
        }
        return Map()
    } catch {
        return Map()
    }
}

; ============================================================
; ★★★ 解析完整 JSONBin 响应 ★★★
; ============================================================
ParseFullJSONBinResponse(jsonStr) {
    result := Map()
    cards := Map()
    
    if RegExMatch(jsonStr, '"record":\s*({.*})', &recordMatch) {
        recordStr := recordMatch[1]
        
        if RegExMatch(recordStr, '"global_config":\s*\{([^}]*)\}', &configMatch) {
            configStr := configMatch[1]
            globalConfig := Map()
            if RegExMatch(configStr, '"bet_delay":\s*(\d+)', &betMatch) {
                globalConfig["bet_delay"] := betMatch[1]
            } else {
                globalConfig["bet_delay"] := 2000
            }
            if RegExMatch(configStr, '"click_delay":\s*(\d+)', &clickMatch) {
                globalConfig["click_delay"] := clickMatch[1]
            } else {
                globalConfig["click_delay"] := 500
            }
            result["global_config"] := globalConfig
        }
        
        if RegExMatch(recordStr, '"cards":\s*({.*})', &cardsMatch) {
            cardsStr := cardsMatch[1]
            pattern := '"([^"]+)"\s*:\s*\{([^}]*)\}'
            pos := 1
            while pos := RegExMatch(cardsStr, pattern, &matchObj, pos) {
                key := matchObj[1]
                infoStr := matchObj[2]
                expiry := ""
                if RegExMatch(infoStr, '"expiry":\s*"([^"]+)"', &expMatch) {
                    expiry := expMatch[1]
                }
                status := ""
                if RegExMatch(infoStr, '"status":\s*"([^"]+)"', &statusMatch) {
                    status := statusMatch[1]
                }
                machine := ""
                if RegExMatch(infoStr, '"machine":\s*"([^"]*)"', &macMatch) {
                    machine := macMatch[1]
                }
                user := ""
                if RegExMatch(infoStr, '"user":\s*"([^"]*)"', &userMatch) {
                    user := userMatch[1]
                }
                activationDate := ""
                if RegExMatch(infoStr, '"activation_date":\s*"([^"]*)"', &actMatch) {
                    activationDate := actMatch[1]
                }
                cardInfo := Map()
                cardInfo["expiry"] := expiry
                cardInfo["status"] := status
                cardInfo["machine"] := machine
                cardInfo["user"] := user
                cardInfo["activation_date"] := activationDate
                cards[key] := cardInfo
                pos += StrLen(matchObj[0])
            }
        }
    }
    
    result["cards"] := cards
    return result
}

SaveBindingToCloud(key, machineID) {
    global JSONBIN_BIN_ID, JSONBIN_API_KEY
    currentData := ReadCardsFromJSONBin()
    if currentData.Count == 0 {
        WriteLog("❌ 读取云端数据失败", 1)
        return false
    }
    if !currentData.Has(key) {
        WriteLog("❌ 卡密不存在: " . key, 1)
        return false
    }
    
    card := currentData[key]
    activationDate := card.Has("activation_date") && card["activation_date"] != "" ? card["activation_date"] : FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    
    ; ★★★ 构建更新数据（跳过 global_config 和 metadata） ★★★
    updateData := "{"
    updateData .= '"cards":{'
    first := true
    for k, v in currentData {
        ; ★★★ 跳过非卡密数据 ★★★
        if (k = "global_config" || k = "metadata") {
            continue
        }
        if !first {
            updateData .= ","
        }
        first := false
        updateData .= '"' . k . '":{'
        updateData .= '"expiry":"' . v["expiry"] . '",'
        updateData .= '"status":"' . (k = key ? "active" : v["status"]) . '",'
        updateData .= '"machine":"' . (k = key ? machineID : v["machine"]) . '",'
        updateData .= '"user":"' . v["user"] . '"'
        if (k = key) {
            updateData .= ',"activation_date":"' . activationDate . '"'
        } else if v.Has("activation_date") && v["activation_date"] != "" {
            updateData .= ',"activation_date":"' . v["activation_date"] . '"'
        }
        updateData .= "}"
    }
    updateData .= "},"
    
    ; ★★★ 保留 global_config ★★★
    if currentData.Has("global_config") {
        updateData .= '"global_config":{'
        updateData .= '"bet_delay":' . (currentData["global_config"].Has("bet_delay") ? currentData["global_config"]["bet_delay"] : 500) . ','
        updateData .= '"click_delay":' . (currentData["global_config"].Has("click_delay") ? currentData["global_config"]["click_delay"] : 500)
        updateData .= "}"
    } else {
        updateData .= '"global_config":{"bet_delay":500,"click_delay":500}'
    }
    
    updateData .= "}"
    
    WriteLog("📤 绑定数据: " . updateData, 2)
    
    headers := Map()
    headers["X-Master-Key"] := JSONBIN_API_KEY
    headers["Content-Type"] := "application/json"
    url := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID
    
    response := HttpRequest(url, headers, "PUT", updateData)
    if response != "" {
        WriteLog("✅ 设备绑定成功: " . key . " -> " . machineID, 2)
        return true
    } else {
        WriteLog("❌ 设备绑定失败", 1)
        return false
    }
}

; ============================================================
; ★★★ 卡密脱敏函数 ★★★
; ============================================================
MaskKey(key) {
    if (StrLen(key) <= 4) {
        return "****"
    }
    first := SubStr(key, 1, 2)
    last := SubStr(key, -1)
    return first . "****" . last
}

; ============================================================
; ★★★ 获取卡密类型 ★★★
; ============================================================
GetCardType(key) {
    if (key = "Weiwei860927") {
        return "管理卡"
    } else if SubStr(key, 1, 2) = "NK" {
        return "年卡"
    } else if SubStr(key, 1, 2) = "JK" {
        return "季卡"
    } else if SubStr(key, 1, 2) = "YK" {
        return "月卡"
    }
    return "月卡"
}

; ============================================================
; ★★★ 计算到期时间 ★★★
; ============================================================
CalcExpiryFromActivation(cardType, activationDateStr) {
    if (activationDateStr == "" || activationDateStr == "未记录") {
        return "未知"
    }
    activationDate := StrReplace(activationDateStr, "-", "")
    activationDate := StrReplace(activationDate, " ", "")
    activationDate := StrReplace(activationDate, ":", "")
    
    days := 0
    if (cardType = "管理卡") {
        return "永久"
    } else if (cardType = "年卡") {
        days := 365
    } else if (cardType = "季卡") {
        days := 90
    } else {
        days := 30
    }
    
    result := DateAdd(activationDate, days, "days")
    year := SubStr(result, 1, 4)
    month := SubStr(result, 5, 2)
    day := SubStr(result, 7, 2)
    hour := SubStr(result, 9, 2)
    min := SubStr(result, 11, 2)
    sec := SubStr(result, 13, 2)
    return year . "-" . month . "-" . day . " " . hour . ":" . min . ":" . sec
}

CalcExpiry(cardType, currentDate) {
    days := 0
    if (cardType = "管理卡") {
        return "永久"
    } else if (cardType = "年卡") {
        days := 365
    } else if (cardType = "季卡") {
        days := 90
    } else {
        days := 30
    }
    result := DateAdd(currentDate, days, "days")
    year := SubStr(result, 1, 4)
    month := SubStr(result, 5, 2)
    day := SubStr(result, 7, 2)
    hour := SubStr(result, 9, 2)
    min := SubStr(result, 11, 2)
    sec := SubStr(result, 13, 2)
    return year . "-" . month . "-" . day . " " . hour . ":" . min . ":" . sec
}

; ============================================================
; ★★★ JSONBin 卡密验证 ★★★
; ============================================================
VerifyKeyOnline(key) {
    global CARDS_DATA
    if (key == "") {
        result := Map()
        result["success"] := false
        result["message"] := "请输入卡密"
        return result
    }
    
    CARDS_DATA := ReadCardsFromJSONBin()
    if (CARDS_DATA.Count == 0) {
        result := Map()
        result["success"] := false
        result["message"] := "网络连接失败，请检查网络"
        return result
    }
    
    matchedKey := ""
    for k, v in CARDS_DATA {
        if (StrLower(k) = StrLower(key)) {
            matchedKey := k
            break
        }
    }
    
    if (matchedKey = "") {
        result := Map()
        result["success"] := false
        result["message"] := "卡密不存在"
        return result
    }
    
    card := CARDS_DATA[matchedKey]
    if (card["status"] != "active") {
        result := Map()
        result["success"] := false
        result["message"] := "卡密已失效或已被禁用"
        return result
    }
    
    today := FormatTime(A_Now, "yyyyMMdd")
    expiryNum := StrReplace(card["expiry"], "-", "")
    if (expiryNum < today) {
        result := Map()
        result["success"] := false
        result["message"] := "卡密已过期"
        return result
    }
    
    isAdminCard := (StrLower(key) = "weiwei860927")
    if isAdminCard {
        result := Map()
        result["success"] := true
        data := Map()
        data["key"] := key
        data["user"] := card["user"]
        data["expiry"] := card["expiry"]
        data["machine"] := "管理卡-无需绑定"
        data["isAdmin"] := true
        data["activation_date"] := card.Has("activation_date") ? card["activation_date"] : ""
        result["data"] := data
        return result
    }
    
    machine := GetMachineID()
    cloudBinding := card["machine"]
    
    if (cloudBinding != "" && cloudBinding != machine) {
        msg := "❌ 卡密已绑定其他设备！`n`n"
        msg .= "当前设备: " . SubStr(machine, 1, 16) . "****`n"
        msg .= "已绑定:   " . SubStr(cloudBinding, 1, 16) . "****`n`n"
        msg .= "如需换机，请使用脚本中的「换机申请」功能"
        
        result := Map()
        result["success"] := false
        result["message"] := msg
        return result
    }
    
    if (cloudBinding == "") {
        if SaveBindingToCloud(matchedKey, machine) {
            cloudBinding := machine
            CARDS_DATA := ReadCardsFromJSONBin()
            if CARDS_DATA.Has(matchedKey) {
                card := CARDS_DATA[matchedKey]
            }
        } else {
            result := Map()
            result["success"] := false
            result["message"] := "绑定设备失败，请检查网络"
            return result
        }
    }
    
    result := Map()
    result["success"] := true
    data := Map()
    data["key"] := key
    data["user"] := card["user"]
    data["expiry"] := card["expiry"]
    data["machine"] := cloudBinding
    data["isAdmin"] := false
    data["activation_date"] := card.Has("activation_date") ? card["activation_date"] : ""
    result["data"] := data
    return result
}

; ============================================================
; ★★★ 验证窗口 ★★★
; ============================================================
VerifyKey() {
    global IsAuthorized, ScriptVersion
    global GuiMain
    global CurrentUserKey
    global UserInfo
    global g_ActualKey, g_KeyInput
    
    if IsAuthorized {
        return true
    }
    
    g_ActualKey := ""
    
    GuiMain := Gui("+OwnDialogs")
    GuiMain.Title := "卡密验证系统"
    GuiMain.Icon := A_ScriptFullPath
    
    GuiMain.SetFont("s14", "微软雅黑")
    GuiMain.Add("Text", "x15 y15 w330 h35 Center c9C7A3A", "★★★胜天半子工作室★★★")
    
    GuiMain.SetFont("s9", "微软雅黑")
    GuiMain.Add("Text", "x15 y52 w330 h1 0x10 c808080")
    
    GuiMain.SetFont("s8", "微软雅黑")
    GuiMain.Add("Text", "x15 y62 w330 h20 Center", "云端验证 · 一卡一机 · 设备绑定")
    GuiMain.SetFont("s10", "微软雅黑")
    
    keyInput := GuiMain.Add("Edit", "x45 y92 w270 h30 Password vKeyInput")
    g_KeyInput := keyInput
    
    keyInput.OnEvent("Change", OnKeyInputChange)
    
    btnVerify := GuiMain.Add("Button", "x100 y137 w160 h40 Default", "验证")
    btnVerify.OnEvent("Click", VerifyButton)
    
    statusText := GuiMain.Add("Text", "x15 y192 w330 h25 Center", "请输入卡密进行验证")
    machineID := GetMachineID()
    displayID := SubStr(machineID, 1, 16) . "****" . SubStr(machineID, -4)
    GuiMain.Add("Text", "x15 y227 w330 h25 Center", "当前设备指纹: " . displayID)
    GuiMain.Add("Text", "x15 y257 w330 h20 Center cGray", "首次验证自动绑定设备")
    
    GuiMain.SetFont("s8", "微软雅黑")
    GuiMain.Add("Text", "x15 y282 w330 h20 Center cGray", "开发者土豆号Potato：@huan16")
    
    GuiMain.SetFont("s8", "微软雅黑")
    GuiMain.Add("Text", "x15 y307 w330 h20 Center cGray", "版本号：" . ScriptVersion)
    
    GuiMain.OnEvent("Close", (*) => ExitApp())
    
    GuiMain.Show("w360 h350")
    return false
    
    OnKeyInputChange(*) {
        global g_ActualKey, g_KeyInput
        if IsObject(g_KeyInput) {
        }
    }
    
    VerifyButton(*) {
        global IsAuthorized, CurrentUserKey, UserInfo, CARDS_DATA, ScriptVersion
        global g_ActualKey, g_KeyInput
        
        key := ""
        try {
            ControlGetText(&key, keyInput.Hwnd)
        } catch {
            try {
                key := keyInput.Text
            } catch {
                key := ""
            }
        }
        
        if (key == "") {
            try {
                WinGetText(&winText, GuiMain.Hwnd)
                if RegExMatch(winText, "输入框:?\s*([^\n]+)", &match) {
                    key := match[1]
                }
            } catch {
            }
        }
        
        if (key == "") {
            try {
                keyInput.Focus()
                Sleep 100
                Send "^a"
                Sleep 100
                Send "^c"
                Sleep 100
                key := Trim(A_Clipboard)
                if (key == "" || RegExMatch(key, "^\*+$")) {
                    key := g_ActualKey
                }
            } catch {
            }
        }
        
        if (key == "") {
            try {
                len := DllCall("GetWindowTextLength", "Ptr", keyInput.Hwnd, "Int")
                if (len > 0) {
                    VarSetStrCapacity(&buf, len + 1)
                    DllCall("GetWindowText", "Ptr", keyInput.Hwnd, "Str", buf, "Int", len + 1)
                    key := buf
                }
            } catch {
            }
        }
        
        if (key != "" && RegExMatch(key, "^\*+$")) {
            key := g_ActualKey
        }
        
        key := Trim(key)
        if (key == "") {
            statusText.Text := "请输入卡密！"
            statusText.SetFont("cRed")
            return
        }
        
        statusText.Text := "正在验证..."
        statusText.SetFont("cBlue")
        GuiMain.Opt("+Disabled")
        result := VerifyKeyOnline(key)
        GuiMain.Opt("-Disabled")
        
        if (!result["success"]) {
            maskedKey := MaskKey(key)
            WriteLog("❌ 验证失败 - " . result["message"] . " 卡密: " . maskedKey, 0)
            statusText.Text := result["message"]
            statusText.SetFont("cRed")
            GuiMain["KeyInput"].Text := ""
            g_ActualKey := ""
            GuiMain["KeyInput"].Focus()
            return
        }
        
        IsAuthorized := true
        CurrentUserKey := key
        UserInfo := result["data"]

        ; ★★★ 从云端读取全局延迟配置 ★★★
        ReadCardsFromJSONBin()
        
        if GlobalConfig.Has("bet_delay") && GlobalConfig["bet_delay"] != "" {
            UserConfig["BetDelay"] := Integer(GlobalConfig["bet_delay"])
            WriteLog("📥 读取云端下注延迟: " . UserConfig["BetDelay"], 2)
        } else {
            UserConfig["BetDelay"] := 500
            WriteLog("⚠️ 使用默认下注延迟: 500", 2)
        }
        
        if GlobalConfig.Has("click_delay") && GlobalConfig["click_delay"] != "" {
            UserConfig["ClickDelay"] := Integer(GlobalConfig["click_delay"])
            WriteLog("📥 读取云端点击延迟: " . UserConfig["ClickDelay"], 2)
        } else {
            UserConfig["ClickDelay"] := 500
            WriteLog("⚠️ 使用默认点击延迟: 500", 2)
        }
        
        WriteLog("📝 最终延迟参数: 下注=" . UserConfig["BetDelay"] . ", 点击=" . UserConfig["ClickDelay"], 2)

                cardType := GetCardType(key)
        isAdmin := (key = "Weiwei860927")
        
        cardInfo := CARDS_DATA[key]
        activationDate := ""
        if IsObject(cardInfo) {
            try {
                if cardInfo.Has("activation_date") {
                    activationDate := cardInfo["activation_date"]
                }
            } catch {
                activationDate := ""
            }
        }
        
        if (activationDate == "" && !isAdmin) {
            activationDate := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            if SaveBindingToCloud(key, GetMachineID()) {
                WriteLog("✅ 首次激活，记录激活日期: " . activationDate, 2)
                CARDS_DATA := ReadCardsFromJSONBin()
                if CARDS_DATA.Has(key) {
                    try {
                        if IsObject(CARDS_DATA[key]) && CARDS_DATA[key].Has("activation_date") {
                            activationDate := CARDS_DATA[key]["activation_date"]
                        }
                    } catch {
                        activationDate := ""
                    }
                }
            }
        }
        
        if (isAdmin) {
            expiryTime := "永久"
        } else if (activationDate != "") {
            expiryTime := CalcExpiryFromActivation(cardType, activationDate)
        } else {
            expiryTime := CalcExpiry(cardType, A_Now)
            activationDate := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        }
        
        displayActivation := activationDate != "" ? activationDate : "未记录"
        maskedKey := MaskKey(key)
        
        WriteLog("✅ 验证成功 - 用户: " . UserInfo["user"] . " 卡密: " . maskedKey, 2)
        WriteLog("卡类型: " . cardType . " 激活: " . displayActivation . " 到期: " . expiryTime, 2)
        WriteLog("设备绑定: " . (isAdmin ? "管理卡-无需绑定" : UserInfo["machine"]), 2)
        
        if isAdmin {
            bindInfo := "⭐ 管理卡 - 不受设备绑定限制`n可在任意设备上使用"
        } else {
            currentMachine := GetMachineID()
            localMachine := UserInfo["machine"]
            if (localMachine = "" || localMachine = "管理卡-无需绑定") {
                bindInfo := "✅ 卡密已绑定当前设备"
            } else if (localMachine = currentMachine) {
                bindInfo := "✅ 已绑定当前设备"
            } else {
                bindInfo := "⚠️ 已绑定设备: " . SubStr(localMachine, 1, 16) . "****"
            }
        }
        
        msg := "✅ 验证成功！`n`n卡类型: " . cardType . "`n激活日期: " . displayActivation . "`n到期时间: " . expiryTime . "`n`n" . bindInfo
        CustomMsgBox("验证结果", msg)
        GuiMain.Destroy()
        Sleep 300
        
        SetTimer(ShowSettingsGUI, -10)
    }
}
    
DisableCloseButton(hwnd) {
    hMenu := DllCall("GetSystemMenu", "Ptr", hwnd, "Int", 0, "Ptr")
    if hMenu {
        DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", 0xF060, "UInt", 0x00000001)
        DllCall("DrawMenuBar", "Ptr", hwnd)
    }
}

; ★★★ 重置时间检测变量 ★★★
ResetTimeDetection() {
    global LastJTime, SameTimeCount
    LastJTime := ""
    SameTimeCount := 0
    WriteLog("🔄 已重置时间检测 (LastJTime, SameTimeCount)", 2)
}

; ============================================================
; ★★★ 在线更新功能 ★★★
; ============================================================
CheckForUpdate() {
    global ScriptVersion
    
    try {
        http := ComObject("Msxml2.XMLHTTP.6.0")
        http.Open("GET", "https://raw.githubusercontent.com/649123301-svg/91bjl/main/version.txt", false)
        http.Send()
        remoteVer := Trim(http.ResponseText)
    } catch {
        CustomMsgBox("检查新版本", "连接失败！请检查网络后重试。")
        return
    }
    
    if (remoteVer == "") {
        CustomMsgBox("检查新版本", "版本号为空！")
        return
    }
    
    remoteVer := SubStr(remoteVer, 1, 6)
    localVer := SubStr(ScriptVersion, 1, 6)
    
    if (localVer == remoteVer) {
        CustomMsgBox("检查新版本", "✅ 当前已是最新版本！`n`n当前版本: " . ScriptVersion)
        return
    }
    
    result := MsgBox("发现新版本！`n`n当前版本: " . ScriptVersion . "`n最新版本: " . remoteVer . "`n`n是否立即更新？", "检查新版本", "YesNo Icon!")
    if (result != "Yes") {
        return
    }
    
    DoUpdate(remoteVer)
}
    
; ============================================================
; ★★★ 在线更新 ★★★
; ============================================================
DoUpdate(remoteVer) {
    global ScriptVersion
    
    ScriptName := "91XZ.exe"
    tempFile := A_Temp . "\" . ScriptName
    downloadUrl := "https://raw.githubusercontent.com/649123301-svg/91bjl/main/91XZ.exe"
    
    MsgBox "正在下载最新版本..."
    
    try {
        http := ComObject("Msxml2.XMLHTTP.6.0")
        http.Open("GET", downloadUrl, false)
        http.Send()
        
        if (http.Status != 200) {
            CustomMsgBox("在线升级", "下载失败！HTTP状态码: " . http.Status . "`n`n下载地址: " . downloadUrl)
            return
        }
        
        ado := ComObject("ADODB.Stream")
        ado.Type := 1
        ado.Open()
        ado.Write(http.ResponseBody)
        ado.SaveToFile(tempFile, 2)
        ado.Close()
    } catch as err {
        CustomMsgBox("在线升级", "下载失败！`n`n" . err.Message)
        return
    }
    
    if !FileExist(tempFile) {
        CustomMsgBox("在线升级", "下载失败，文件不存在！")
        return
    }
    
    fileSize := FileGetSize(tempFile)
    CustomMsgBox("在线升级", "✅ 下载成功！`n`n文件大小: " . fileSize . " 字节")
    
    batchFile := A_Temp . "\update_" . A_TickCount . ".bat"
    
    try {
        if FileExist(batchFile) {
            FileDelete(batchFile)
        }
    } catch {
    }
    
    SplitPath(A_ScriptFullPath, &currentFileName)
    
    FileAppend('@echo off`n', batchFile)
    FileAppend('chcp 65001 >nul`n', batchFile)
    FileAppend('timeout /t 2 /nobreak >nul`n', batchFile)
    FileAppend('`n', batchFile)
    FileAppend(':loop`n', batchFile)
    FileAppend('tasklist | find /i "' . currentFileName . '" >nul`n', batchFile)
    FileAppend('if not errorlevel 1 (`n', batchFile)
    FileAppend('  timeout /t 1 /nobreak >nul`n', batchFile)
    FileAppend('  goto loop`n', batchFile)
    FileAppend(')`n', batchFile)
    FileAppend('`n', batchFile)
    FileAppend('copy /y "' . tempFile . '" "' . A_ScriptDir . '\' . ScriptName . '"`n', batchFile)
    FileAppend('del "' . tempFile . '"`n', batchFile)
    FileAppend('`n', batchFile)
    FileAppend('echo ' . remoteVer . ' > "' . A_ScriptDir . '\version.txt"`n', batchFile)
    FileAppend('`n', batchFile)
    FileAppend('start "" "' . A_ScriptDir . '\' . ScriptName . '"`n', batchFile)
    FileAppend('`n', batchFile)
    FileAppend('del %~f0`n', batchFile)
    
    try {
        Run(batchFile, A_Temp, "Hide")
    } catch as err {
        CustomMsgBox("在线升级", "启动更新失败！`n`n" . err.Message)
        return
    }
    
    WriteLog("正在更新到版本: " . remoteVer, 2)
    ExitApp()
}

; ============================================================
; ★★★ 管理员解绑界面 ★★★
; ============================================================
ShowAdminUnbindGUI(*) {
    global CurrentUserKey
    if (CurrentUserKey != "Weiwei860927") {
        CustomMsgBox("提示", "需要管理卡权限")
        return
    }
    
    adminGui := Gui()
    adminGui.Title := "🔓 管理员解绑"
    adminGui.SetFont("s10", "微软雅黑")
    
    adminGui.Add("Text", "x15 y15 w300 h25 Center", "请输入需要解绑的卡密")
    adminGui.SetFont("s9", "微软雅黑")
    adminGui.Add("Text", "x15 y50 w300 h20 Center cGray", "输入完整卡密，点击解绑即可")
    
    keyInput := adminGui.Add("Edit", "x30 y80 w240 h30")
    btnUnbind := adminGui.Add("Button", "x60 y130 w80 h35 Default", "解绑")
    btnUnbind.OnEvent("Click", (*) => DoAdminUnbind(keyInput.Text, adminGui))
    
    btnClose := adminGui.Add("Button", "x190 y130 w80 h35", "关闭")
    btnClose.OnEvent("Click", (*) => adminGui.Destroy())
    
    adminGui.OnEvent("Close", (*) => adminGui.Destroy())
    OnMessage(0x112, WM_SYSCOMMAND)
    
    adminGui.Show("w330 h200")
    
    SetTimer(CheckAdminGuiClose, 100)
    
    CheckAdminGuiClose() {
        global adminGui
        try {
            if !WinExist("🔓 管理员解绑") {
                try adminGui.Destroy()
                SetTimer(CheckAdminGuiClose, 0)
            }
        }
    }
}

WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    if (wParam = 0xF060) {
        try {
            WinClose("🔓 管理员解绑")
            return 0
        }
    }
}

DoAdminUnbind(key, gui) {
    key := Trim(key)
    if (key == "") {
        CustomMsgBox("提示", "请输入卡密")
        return
    }
    AdminUnbindCard(key)
    gui.Destroy()
}

; ============================================================
; ★★★ 管理员解绑功能 ★★★
; ============================================================
AdminUnbindCard(key) {
    global JSONBIN_BIN_ID, JSONBIN_API_KEY, CARDS_DATA, CurrentUserKey
    
    if (CurrentUserKey != "Weiwei860927") {
        CustomMsgBox("提示", "只有管理卡才能执行解绑操作")
        return false
    }
    
    if (key == "" || key == "Weiwei860927") {
        CustomMsgBox("提示", "不能解绑管理卡本身")
        return false
    }
    
    currentData := ReadCardsFromJSONBin()
    if !currentData.Has(key) {
        CustomMsgBox("错误", "卡密不存在")
        return false
    }
    
    result := MsgBox("⚠️ 确认解绑卡密: " . MaskKey(key) . "？`n`n当前绑定设备: " . currentData[key]["machine"], "解绑确认", "YesNo Icon!")
    if (result != "Yes") {
        return false
    }
    
    updateData := "{"
    first := true
    for k, v in currentData {
        if !first {
            updateData .= ","
        }
        first := false
        updateData .= '"' . k . '":{'
        updateData .= '"expiry":"' . v["expiry"] . '",'
        updateData .= '"status":"' . v["status"] . '",'
        updateData .= '"machine":"' . (k = key ? "" : v["machine"]) . '",'
        updateData .= '"user":"' . v["user"] . '"'
        if (k = key) {
            updateData .= ',"activation_date":"' . v["activation_date"] . '"'
        } else if v.Has("activation_date") && v["activation_date"] != "" {
            updateData .= ',"activation_date":"' . v["activation_date"] . '"'
        }
        updateData .= "}"
    }
    updateData .= "}"
    
    headers := Map()
    headers["X-Master-Key"] := JSONBIN_API_KEY
    headers["Content-Type"] := "application/json"
    url := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID
    response := HttpRequest(url, headers, "PUT", '{"cards":' . updateData . '}')
    
    if response != "" {
        WriteLog("✅ 管理员解绑卡密: " . MaskKey(key), 2)
        CustomMsgBox("解绑成功", "✅ 卡密 " . MaskKey(key) . " 已成功解绑`n`n用户可以在新设备上重新验证")
        CARDS_DATA := ReadCardsFromJSONBin()
        return true
    } else {
        CustomMsgBox("解绑失败", "❌ 网络错误，解绑失败！请检查网络后重试")
        return false
    }
}

; ============================================================
; ★★★ 更新下注延迟（只更新本地） ★★★
; ============================================================
UpdateBetDelay(value) {
    global UserConfig
    if !IsNumber(value) || value <= 0 {
        WriteLog("⚠️ 下注延迟输入无效: " . value, 1)
        return
    }
    UserConfig["BetDelay"] := Integer(value)
    WriteLog("📝 下注延迟已更新为: " . UserConfig["BetDelay"], 2)
}

; ============================================================
; ★★★ 更新点击延迟（只更新本地） ★★★
; ============================================================
UpdateClickDelay(value) {
    global UserConfig
    if !IsNumber(value) || value <= 0 {
        WriteLog("⚠️ 点击延迟输入无效: " . value, 1)
        return
    }
    UserConfig["ClickDelay"] := Integer(value)
    WriteLog("📝 点击延迟已更新为: " . UserConfig["ClickDelay"], 2)
}

; ============================================================
; ★★★ 同步延迟参数到云端 ★★★
; ============================================================
SyncDelayToCloud(key, field, value) {
    global JSONBIN_BIN_ID, JSONBIN_API_KEY, CARDS_DATA
    
    WriteLog("☁️ 正在同步 " . field . "=" . value . " 到云端...", 2)
    
    currentData := ReadCardsFromJSONBin()
    if currentData.Count == 0 {
        WriteLog("❌ 读取云端数据失败", 1)
        ToolTip "❌ 读取云端数据失败"
        SetTimer(ToolTipClear, -2000)
        return
    }
    if !currentData.Has(key) {
        WriteLog("❌ 卡密不存在", 1)
        return
    }
    
    v := currentData[key]
    
    currentBetDelay := 2000
    currentClickDelay := 500
    
    if v.Has("bet_delay") && v["bet_delay"] != "" {
        currentBetDelay := v["bet_delay"]
    }
    if v.Has("click_delay") && v["click_delay"] != "" {
        currentClickDelay := v["click_delay"]
    }
    
    WriteLog("📋 读取到云端值: bet_delay=" . currentBetDelay . ", click_delay=" . currentClickDelay, 2)
    
    if (field = "bet_delay") {
        currentBetDelay := value
        WriteLog("📝 更新 bet_delay = " . value, 2)
    } else if (field = "click_delay") {
        currentClickDelay := value
        WriteLog("📝 更新 click_delay = " . value, 2)
    }
    
    WriteLog("📋 更新后值: bet_delay=" . currentBetDelay . ", click_delay=" . currentClickDelay, 2)
    
    updateData := "{"
    first := true
    for k, v in currentData {
        if !first {
            updateData .= ","
        }
        first := false
        updateData .= '"' . k . '":{'
        updateData .= '"expiry":"' . v["expiry"] . '",'
        updateData .= '"status":"' . v["status"] . '",'
        updateData .= '"machine":"' . v["machine"] . '",'
        updateData .= '"user":"' . v["user"] . '"'
        
        if v.Has("activation_date") && v["activation_date"] != "" {
            updateData .= ',"activation_date":"' . v["activation_date"] . '"'
        }
        
        if (k = key) {
            updateData .= ',"bet_delay":' . currentBetDelay
            updateData .= ',"click_delay":' . currentClickDelay
            WriteLog("🎯 目标卡密写入: bet_delay=" . currentBetDelay . ", click_delay=" . currentClickDelay, 2)
        } else {
            if v.Has("bet_delay") && v["bet_delay"] != "" {
                updateData .= ',"bet_delay":' . v["bet_delay"]
            } else {
                updateData .= ',"bet_delay":2000'
            }
            if v.Has("click_delay") && v["click_delay"] != "" {
                updateData .= ',"click_delay":' . v["click_delay"]
            } else {
                updateData .= ',"click_delay":500'
            }
        }
        
        updateData .= "}"
    }
    updateData .= "}"
    
    WriteLog("📤 上传数据: " . updateData, 2)
    
    headers := Map()
    headers["X-Master-Key"] := JSONBIN_API_KEY
    headers["Content-Type"] := "application/json"
    url := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID
    
    jsonData := '{"cards":' . updateData . '}'
    
    response := HttpRequest(url, headers, "PUT", jsonData)
    if response != "" {
        WriteLog("✅ 延迟参数已同步到云端: " . field . "=" . value, 2)
        WriteLog("✅ 当前云端值: bet_delay=" . currentBetDelay . ", click_delay=" . currentClickDelay, 2)
        CARDS_DATA := ReadCardsFromJSONBin()
        ToolTip "✅ " . (field = "bet_delay" ? "下注延迟" : "点击延迟") . "已上传: " . value . " ms"
        SetTimer(ToolTipClear, -2000)
    } else {
        WriteLog("❌ 同步到云端失败", 1)
        ToolTip "❌ 上传失败，请检查网络"
        SetTimer(ToolTipClear, -2000)
    }
}

; ============================================================
; ★★★ 同步全局延迟参数到云端 ★★★
; ============================================================
SyncDelayToCloudAll(key, betDelay, clickDelay) {
    global JSONBIN_BIN_ID, JSONBIN_API_KEY, GlobalConfig, CARDS_DATA
    
    WriteLog("☁️ 正在同步全局配置: bet_delay=" . betDelay . ", click_delay=" . clickDelay . " 到云端...", 2)
    
    ; ★★★ 直接从云端读取最新数据 ★★★
    headers := Map()
    headers["X-Master-Key"] := JSONBIN_API_KEY
    url := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID . "/latest"
    
    http := ComObject("Msxml2.XMLHTTP.6.0")
    http.Open("GET", url, false)
    http.SetRequestHeader("X-Master-Key", JSONBIN_API_KEY)
    http.Send()
    
    if http.Status != 200 {
        WriteLog("❌ 读取云端数据失败", 1)
        ToolTip "❌ 读取云端数据失败"
        SetTimer(ToolTipClear, -2000)
        return
    }
    
    response := http.ResponseText
    ; ★★★ 解析 JSON 获取 record ★★★
    if !RegExMatch(response, '"record":\s*({.*})', &recordMatch) {
        WriteLog("❌ 解析云端数据失败", 1)
        return
    }
    recordStr := recordMatch[1]
    
    ; ★★★ 构建完整的更新数据（保留原有的 record 结构） ★★★
    ; 先提取 cards 部分
    cardsStr := ""
    if RegExMatch(recordStr, '"cards":\s*({.*?})(?=,"global_config"|$)', &cardsMatch) {
        cardsStr := cardsMatch[1]
    } else if RegExMatch(recordStr, '"cards":\s*({.*})', &cardsMatch) {
        cardsStr := cardsMatch[1]
    }
    
    ; ★★★ 构建上传数据 ★★★
    updateData := "{"
    updateData .= '"cards":' . cardsStr . ','
    updateData .= '"global_config":{'
    updateData .= '"bet_delay":' . betDelay . ','
    updateData .= '"click_delay":' . clickDelay
    updateData .= "}"
    updateData .= "}"
    
    WriteLog("📤 上传数据: " . updateData, 2)
    
    ; ★★★ 上传到云端 ★★★
    headers2 := Map()
    headers2["X-Master-Key"] := JSONBIN_API_KEY
    headers2["Content-Type"] := "application/json"
    url2 := "https://api.jsonbin.io/v3/b/" . JSONBIN_BIN_ID
    
    http2 := ComObject("Msxml2.XMLHTTP.6.0")
    http2.Open("PUT", url2, false)
    http2.SetRequestHeader("X-Master-Key", JSONBIN_API_KEY)
    http2.SetRequestHeader("Content-Type", "application/json")
    http2.Send(updateData)
    
    if http2.Status = 200 {
        WriteLog("✅ 全局配置已同步到云端: bet_delay=" . betDelay . ", click_delay=" . clickDelay, 2)
        GlobalConfig["bet_delay"] := betDelay
        GlobalConfig["click_delay"] := clickDelay
        ToolTip "✅ 已保存全局延迟: 下注=" . betDelay . ", 点击=" . clickDelay
        SetTimer(ToolTipClear, -3000)
        ; ★★★ 重新读取缓存 ★★★
        CARDS_DATA := ReadCardsFromJSONBin()
    } else {
        WriteLog("❌ 同步到云端失败，HTTP状态码: " . http2.Status, 1)
        ToolTip "❌ 保存失败，HTTP状态码: " . http2.Status
        SetTimer(ToolTipClear, -2000)
    }
}

; ============================================================
; ★★★ 保存所有延迟 ★★★
; ============================================================
OnSaveAllClick(*) {
    global betDelayEdit, clickDelayEdit, UserConfig, CurrentUserKey
    
    betVal := betDelayEdit.Text
    clickVal := clickDelayEdit.Text
    
    if !IsNumber(betVal) || betVal <= 0 {
        MsgBox "⚠️ 下注延迟请输入有效的数字（大于0）！"
        return
    }
    if !IsNumber(clickVal) || clickVal <= 0 {
        MsgBox "⚠️ 点击延迟请输入有效的数字（大于0）！"
        return
    }
    
    betDelay := Integer(betVal)
    clickDelay := Integer(clickVal)
    
    UserConfig["BetDelay"] := betDelay
    UserConfig["ClickDelay"] := clickDelay
    
    WriteLog("📝 用户点击保存: 下注=" . betDelay . ", 点击=" . clickDelay, 2)
    
    SyncDelayToCloudAll(CurrentUserKey, betDelay, clickDelay)
}

; ============================================================
; ★★★ 设置界面 ★★★
; ============================================================
ShowSettingsGUI() {
    global UserConfig, IsAuthorized, ScriptPaused, StopBetting, SettingsGui, ScriptVersion, CurrentUserKey, CARDS_DATA
    global IsGrabEnabled, GrabLastRunSec
    
    if SettingsGui != "" {
        try {
            SettingsGui.Destroy()
            SettingsGui := ""
            Sleep 200
        } catch {
        }
    }

    SettingsGui := Gui("+OwnDialogs")
    SettingsGui.Title := "⚙️ 脚本设置"
    SettingsGui.Icon := A_ScriptFullPath
    
    SettingsGui.SetFont("s10", "微软雅黑")
    
    SetTimer(() => DisableCloseButton(SettingsGui.Hwnd), -100)
    
    OnMessage(0x112, WM_SYSCOMMAND)
    WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
        if (wParam = 0xF060) {
            return 0
        }
    }
    
    ; ★★★ 判断端口 ★★★
    isUserPort := false
    isHostPort := false
    
    if (CurrentUserKey = "Weiwei860927") {
        isUserPort := true
    } else if (SubStr(CurrentUserKey, 1, 4) = "NKYH" || SubStr(CurrentUserKey, 1, 4) = "YKYH" || SubStr(CurrentUserKey, 1, 4) = "JKYH") {
        isUserPort := true
    } else if (SubStr(CurrentUserKey, 1, 4) = "NKZB" || SubStr(CurrentUserKey, 1, 4) = "YKZB" || SubStr(CurrentUserKey, 1, 4) = "JKZB") {
        isHostPort := true
    } else {
        isUserPort := true
    }
    
    ; ★★★ 标题 ★★★
    if (isHostPort) {
        SettingsGui.Add("Text", "x15 y15 w310 h30 Center", "实时日志")
    } else {
        SettingsGui.Add("Text", "x15 y15 w300 h30 Center", "参数设置")
        SettingsGui.SetFont("s8", "微软雅黑")
        SettingsGui.Add("Text", "x15 y45 w300 h20 Center cBlue", "⚙️ 修改参数后点击「开启下注」即可生效")
    }
    SettingsGui.SetFont("s10", "微软雅黑")
    
    ; ★★★ 用户端 ★★★
    if (isUserPort) {
        ; 止盈设置
        SettingsGui.Add("Text", "x40 y80 w45 h30", "止盈：")
        global stopProfitEdit := SettingsGui.Add("Edit", "x85 y80 w120 h30 vStopProfit", "选填")
        stopProfitEdit.SetFont("cGray")
        stopProfitEdit.OnEvent("Focus", StopProfitFocus)
        stopProfitEdit.OnEvent("LoseFocus", StopProfitLoseFocus)
        SettingsGui.Add("Text", "x210 y80 w20 h30", "元")
        SettingsGui.Add("Text", "x235 y80 w70 h30 cGray", "暂停下注")
        
        ; 止损设置
        SettingsGui.Add("Text", "x40 y120 w45 h30", "止损：")
        global stopLossEdit := SettingsGui.Add("Edit", "x85 y120 w120 h30 vStopLoss", "选填")
        stopLossEdit.SetFont("cGray")
        stopLossEdit.OnEvent("Focus", StopLossFocus)
        stopLossEdit.OnEvent("LoseFocus", StopLossLoseFocus)
        SettingsGui.Add("Text", "x210 y120 w20 h30", "元")
        SettingsGui.Add("Text", "x235 y120 w70 h30 cGray", "暂停下注")
        
        ; 下注延迟
        SettingsGui.Add("Text", "x40 y167 w75 h30", "下注延迟：")
        if (CurrentUserKey = "Weiwei860927") {
            global betDelayEdit := SettingsGui.Add("Edit", "x100 y160 w130 h30 vBetDelay", UserConfig["BetDelay"])
            betDelayEdit.SetFont("cBlack")
            betDelayEdit.OnEvent("LoseFocus", OnBetDelayLoseFocus)
        } else {
            global betDelayEdit := SettingsGui.Add("Edit", "x100 y160 w130 h30 vBetDelay Disabled", UserConfig["BetDelay"])
            betDelayEdit.SetFont("cGray")
        }
        SettingsGui.Add("Text", "x235 y160 w30 h30 cGray", "ms")
        
        if (CurrentUserKey = "Weiwei860927") {
            btnSaveBetDelay := SettingsGui.Add("Button", "x270 y160 w50 h30", "保存")
            btnSaveBetDelay.SetFont("cWhite", "微软雅黑")
            btnSaveBetDelay.BackColor := "Green"
            btnSaveBetDelay.OnEvent("Click", (*) => SaveBetDelayToCloud())
        }
        
        ; 点击延迟
        SettingsGui.Add("Text", "x40 y203 w75 h30", "点击延迟：")
        if (CurrentUserKey = "Weiwei860927") {
            global clickDelayEdit := SettingsGui.Add("Edit", "x100 y200 w130 h30 vClickDelay", UserConfig["ClickDelay"])
            clickDelayEdit.SetFont("cBlack")
            clickDelayEdit.OnEvent("LoseFocus", OnClickDelayLoseFocus)
        } else {
            global clickDelayEdit := SettingsGui.Add("Edit", "x100 y200 w130 h30 vClickDelay Disabled", UserConfig["ClickDelay"])
            clickDelayEdit.SetFont("cGray")
        }
        SettingsGui.Add("Text", "x235 y200 w30 h30 cGray", "ms")
        
        if (CurrentUserKey = "Weiwei860927") {
            btnSaveClickDelay := SettingsGui.Add("Button", "x270 y200 w50 h30", "保存")
            btnSaveClickDelay.SetFont("cWhite", "微软雅黑")
            btnSaveClickDelay.BackColor := "Green"
            btnSaveClickDelay.OnEvent("Click", (*) => SaveClickDelayToCloud())
        }
        
        SettingsGui.SetFont("s10", "微软雅黑")
        SettingsGui.Add("Text", "x15 y245 w300 h1 0x10 c808080")
        
        ; ★★★ 卡密信息 ★★★
        cardInfoText := ""
        if (IsAuthorized && CurrentUserKey != "") {
            cardInfo := CARDS_DATA.Has(CurrentUserKey) ? CARDS_DATA[CurrentUserKey] : Map()
            activationDate := cardInfo.Has("activation_date") ? cardInfo["activation_date"] : "未记录"
            cardType := GetCardType(CurrentUserKey)
            isAdmin := (CurrentUserKey = "Weiwei860927")
            if (isAdmin) {
                expiryTime := "永久"
            } else if (activationDate != "未记录" && activationDate != "") {
                expiryTime := CalcExpiryFromActivation(cardType, activationDate)
            } else {
                expiryTime := "未计算"
            }
            maskedKey := MaskKey(CurrentUserKey)
            portType := "用户端"
            cardInfoText := "卡密: " . maskedKey . " | " . cardType . " | " . portType . " | 到期: " . expiryTime
        }
        if (cardInfoText != "") {
            SettingsGui.Add("Text", "x15 y265 w310 h20 Center cBlue", cardInfoText)
        }
        
        ; ★★★ 版本信息 ★★★
        SettingsGui.SetFont("s9", "微软雅黑")
        SettingsGui.Add("Text", "x50 y300 w70 h30", "版本：")
        SettingsGui.SetFont("s9", "微软雅黑")
        SettingsGui.Add("Text", "x120 y300 w80 h30", ScriptVersion)
        
        btnUpdate := SettingsGui.Add("Button", "x205 y297 w100 h28", "🔍 版本更新")
        btnUpdate.SetFont("cWhite", "微软雅黑")
        btnUpdate.BackColor := "Blue"
        btnUpdate.OnEvent("Click", (*) => CheckForUpdate())
        
        SettingsGui.SetFont("s10", "微软雅黑")
        SettingsGui.Add("Text", "x15 y340 w300 h1 0x10 c808080")
        
        ; ★★★ 用户端按钮 ★★★
        global chkBalance := SettingsGui.Add("Checkbox", "x15 y355 w75 h35 vChkBalance", "本金")
        chkBalance.SetFont("s10", "微软雅黑")
        chkBalance.Enabled := false
        chkBalance.OnEvent("Click", OnBalanceCheck)
        
        global btnBetToggle := SettingsGui.Add("Button", "x100 y355 w105 h35 Default", "开启下注")
        btnBetToggle.SetFont("cWhite", "微软雅黑")
        btnBetToggle.BackColor := "Green"
        btnBetToggle.Enabled := false
        btnBetToggle.OnEvent("Click", ToggleBet)
        
        global btnGrabToggle := SettingsGui.Add("Button", "x215 y355 w110 h35", "开启抓奖")
        btnGrabToggle.SetFont("cWhite", "微软雅黑")
        btnGrabToggle.BackColor := "Green"
        btnGrabToggle.OnEvent("Click", ToggleGrab)
        
        ViewLog(*) {
            ShowLogWindow()
        }
        btnLog := SettingsGui.Add("Button", "x20 y410 w135 h40", "📋 查看日志")
        btnLog.SetFont("cWhite", "微软雅黑")
        btnLog.OnEvent("Click", ViewLog)
        
        btnClose := SettingsGui.Add("Button", "x180 y410 w135 h40", "退出脚本")
        btnClose.SetFont("cWhite", "微软雅黑")
        btnClose.OnEvent("Click", ExitScript)
        
        global statusText := SettingsGui.Add("Text", "x15 y470 w300 h25 Center cRed", "⏸️ 下注已暂停 | 抓奖已停止")
        
        SettingsGui.SetFont("s9", "微软雅黑")
        SettingsGui.Add("Text", "x15 y505 w300 h1 0x10 c808080")
        SettingsGui.SetFont("s10", "微软雅黑")
        SettingsGui.Add("Text", "x15 y515 w300 h25 Center c9C7A3A", "★★★胜天半子工作室 ★★★")
        SettingsGui.SetFont("s8", "微软雅黑")
        
        if (IsAuthorized && CurrentUserKey = "Weiwei860927") {
            btnAdminUnbind := SettingsGui.Add("Button", "x250 y515 w60 h25", "🔓解绑")
            btnAdminUnbind.SetFont("s8", "微软雅黑")
            btnAdminUnbind.OnEvent("Click", ShowAdminUnbindGUI)
        }
        
        SettingsGui.Add("Text", "x15 y540 w300 h20 Center cGray", "开发者土豆号Potato：@huan16")
        
        SettingsGui.btnBetToggle := btnBetToggle
        SettingsGui.btnGrabToggle := btnGrabToggle
        SettingsGui.chkBalance := chkBalance
        SettingsGui.statusText := statusText
        SettingsGui.stopProfitEdit := stopProfitEdit
        SettingsGui.stopLossEdit := stopLossEdit
        SettingsGui.betDelayEdit := betDelayEdit
        SettingsGui.clickDelayEdit := clickDelayEdit
        SettingsGui.btnUpdate := btnUpdate
        
        btnBetToggle.OnEvent("Click", ToggleBet)
        btnGrabToggle.OnEvent("Click", ToggleGrab)
        
        SettingsGui.Show("w340 h570")
        return
    }
    
    ; ★★★ 主播端 ★★★
    if (isHostPort) {
        ; ★★★ 卡密信息（放在按钮上面） ★★★
        cardInfoText2 := ""
        if (IsAuthorized && CurrentUserKey != "") {
            cardInfo := CARDS_DATA.Has(CurrentUserKey) ? CARDS_DATA[CurrentUserKey] : Map()
            activationDate := cardInfo.Has("activation_date") ? cardInfo["activation_date"] : "未记录"
            cardType := GetCardType(CurrentUserKey)
            isAdmin := (CurrentUserKey = "Weiwei860927")
            if (isAdmin) {
                expiryTime := "永久"
            } else if (activationDate != "未记录" && activationDate != "") {
                expiryTime := CalcExpiryFromActivation(cardType, activationDate)
            } else {
                expiryTime := "未计算"
            }
            maskedKey := MaskKey(CurrentUserKey)
            portType := "主播端"
            cardInfoText2 := "卡密: " . maskedKey . " | " . cardType . " | " . portType . " | 到期: " . expiryTime
        }
        if (cardInfoText2 != "") {
            SettingsGui.Add("Text", "x15 y50 w310 h20 Center cBlue", cardInfoText2)
        }
        
        ; ★★★ 实时日志显示框 ★★★
        global LogContent
        logContent := ""
        if (LogContent != "") {
            lines := StrSplit(LogContent, "`n")
            keywords := ["开启抓奖", "停止抓奖", "抓奖已开启", "抓奖已停止", 
                        "闲=", "庄=", "点数", "OCR", "识别结果",
                        "错误", "失败", "异常", 
                        "退出", "进入", "检测",
                        "脚本启动", "脚本版本", "管理员权限", "机器指纹", "验证成功", "脚本就绪"]
            for line in lines {
                if InStr(line, "下注") {
                    continue
                }
                if InStr(line, "止盈") {
                    continue
                }
                if InStr(line, "止损") {
                    continue
                }
                if InStr(line, "本金") {
                    continue
                }
                if InStr(line, "延迟") {
                    continue
                }
                show := false
                for kw in keywords {
                    if InStr(line, kw) {
                        show := true
                        break
                    }
                }
                if show {
                    logContent .= line . "`n"
                }
            }
            allLines := StrSplit(logContent, "`n")
            if allLines.Length > 80 {
                newContent := ""
                startIdx := allLines.Length - 80 + 1
                Loop 80 {
                    idx := startIdx + A_Index - 1
                    if idx <= allLines.Length {
                        newContent .= allLines[idx] . "`n"
                    }
                }
                logContent := newContent
            }
        }
        if (logContent == "") {
            logContent := "等待日志..."
        }
        logEdit := SettingsGui.Add("Edit", "x15 y80 w310 h175 ReadOnly +VScroll", logContent)
        logEdit.SetFont("s9", "Consolas")

        ; ★★★ 实时日志显示框 ★★★
        global LogContent
        logContent := ""
        if (LogContent != "") {
            lines := StrSplit(LogContent, "`n")
            keywords := ["开启抓奖", "停止抓奖", "抓奖已开启", "抓奖已停止", 
                        "闲=", "庄=", "点数", "OCR", "识别结果",
                        "错误", "失败", "异常", 
                        "退出", "进入", "检测",
                        "脚本启动", "脚本版本", "管理员权限", "机器指纹", "验证成功", "脚本就绪",
                        "重置时间检测", "脚本就绪", "抓奖功能", "抓奖流程", "等待用户操作"]
            for line in lines {
                if InStr(line, "下注") {
                    continue
                }
                if InStr(line, "止盈") {
                    continue
                }
                if InStr(line, "止损") {
                    continue
                }
                if InStr(line, "本金") {
                    continue
                }
                if InStr(line, "延迟") {
                    continue
                }
                show := false
                for kw in keywords {
                    if InStr(line, kw) {
                        show := true
                        break
                    }
                }
                if show {
                    logContent .= line . "`n"
                }
            }
            allLines := StrSplit(logContent, "`n")
            if allLines.Length > 80 {
                newContent := ""
                startIdx := allLines.Length - 80 + 1
                Loop 80 {
                    idx := startIdx + A_Index - 1
                    if idx <= allLines.Length {
                        newContent .= allLines[idx] . "`n"
                    }
                }
                logContent := newContent
            }
        }

        
               ; ★★★ 更新日志的定时器（直接从文件读取） ★★★
        UpdateHostLog(*) {
            try {
                ; ★★★ 直接从日志文件读取 ★★★
                logFile := "C:\Users\Administrator\Desktop\zhuajiang\logs\script_log_*.txt"
                ; 获取最新的日志文件
                logFilePath := ""
                Loop Files, "C:\Users\Administrator\Desktop\zhuajiang\logs\*.txt", "F" {
                    logFilePath := A_LoopFileFullPath
                }
                
                if (logFilePath == "") {
                    logEdit.Value := "等待日志..."
                    return
                }
                
                ; 读取文件内容
                fileContent := FileRead(logFilePath)
                if (fileContent == "") {
                    logEdit.Value := "等待日志..."
                    return
                }
                
                ; ★★★ 过滤只显示主播端相关日志 ★★★
                lines := StrSplit(fileContent, "`n")
                filtered := ""
                keywords := ["开启抓奖", "停止抓奖", "抓奖已开启", "抓奖已停止", 
                            "闲=", "庄=", "点数", "OCR", "识别结果",
                            "错误", "失败", "异常", 
                            "退出", "进入", "检测",
                            "脚本启动", "脚本版本", "管理员权限", "机器指纹", "验证成功", "脚本就绪",
                            "重置时间检测", "脚本就绪", "抓奖功能", "抓奖流程", "等待用户操作"]
                count := 0
                for line in lines {
                    ; ★★★ 排除下注相关日志 ★★★
                    if InStr(line, "下注") {
                        continue
                    }
                    if InStr(line, "止盈") {
                        continue
                    }
                    if InStr(line, "止损") {
                        continue
                    }
                    if InStr(line, "本金") {
                        continue
                    }
                    if InStr(line, "延迟") {
                        continue
                    }
                    show := false
                    for kw in keywords {
                        if InStr(line, kw) {
                            show := true
                            break
                        }
                    }
                    if show {
                        filtered .= line . "`n"
                        count += 1
                    }
                }
                if count > 80 {
                    allLines := StrSplit(filtered, "`n")
                    newFiltered := ""
                    startIdx := allLines.Length - 80 + 1
                    Loop 80 {
                        idx := startIdx + A_Index - 1
                        if idx <= allLines.Length {
                            newFiltered .= allLines[idx] . "`n"
                        }
                    }
                    filtered := newFiltered
                }
                if (filtered == "") {
                    filtered := "等待日志..."
                }
                logEdit.Value := filtered
                SendMessage(0x115, 7, 0, logEdit)
            } catch as e {
                ; 出错时静默处理
            }
        }
        SetTimer(UpdateHostLog, 1000)
        
        ; ★★★ 按钮：开启抓奖 + 退出脚本 ★★★
        global btnGrabToggle := SettingsGui.Add("Button", "x30 y280 w130 h45", "开启抓奖")
        btnGrabToggle.SetFont("cWhite s10", "微软雅黑")
        btnGrabToggle.BackColor := "Green"
        btnGrabToggle.OnEvent("Click", ToggleGrab)
        
        btnClose := SettingsGui.Add("Button", "x180 y280 w130 h45", "退出脚本")
        btnClose.SetFont("cWhite s10", "微软雅黑")
        btnClose.BackColor := "Red"
        btnClose.OnEvent("Click", ExitScript)
        
        global statusText := SettingsGui.Add("Text", "x15 y345 w310 h25 Center cRed", "⏸️ 抓奖已停止")
        
        SettingsGui.SetFont("s9", "微软雅黑")
        SettingsGui.Add("Text", "x15 y385 w310 h1 0x10 c808080")
        SettingsGui.SetFont("s10", "微软雅黑")
        SettingsGui.Add("Text", "x15 y395 w310 h25 Center c9C7A3A", "★★★胜天半子工作室 ★★★")
        SettingsGui.SetFont("s8", "微软雅黑")
        SettingsGui.Add("Text", "x15 y420 w310 h20 Center cGray", "开发者土豆号Potato：@huan16")
        
        SettingsGui.btnGrabToggle := btnGrabToggle
        SettingsGui.statusText := statusText
        
        SettingsGui.Show("w340 h460")
        return
    }
}

; ============================================================
; ★★★ 关闭按钮禁用 ★★★
; ============================================================
OnMessage(0x201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global btnBetToggle, SettingsGui
    try {
        if IsObject(SettingsGui) && hwnd = SettingsGui.Hwnd {
            btnBetToggle.Focus()
        }
    } catch {
    }
}

; ============================================================
; ★★★ 开启/停止下注 ★★★
; ============================================================
ToggleBet(*) {
    global ScriptPaused, StopBetting, IsAuthorized, UserConfig, g_Initialized
    global stopProfitEdit, stopLossEdit, btnBetToggle, statusText, IsGrabEnabled, BetAmountResultFile
    global IsBalanceSet, OriginalBalance, chkBalance
    
    if !IsAuthorized {
        statusText.Text := "❌ 请先验证卡密！"
        statusText.SetFont("cRed")
        return
    }
    
    if !IsGrabEnabled {
        CustomMsgBox("提示", "请先开启抓奖，才能开启下注！")
        return
    }
    
; ★★★ 检查本金复选框是否打勾 ★★★
if !chkBalance.Value {
    CustomMsgBox("提示", "❌ 请先勾选「本金」设置本金！")
    return
}
    
    if ScriptPaused {
        ; ★★★ 开启下注 ★★★
        ; 读取止盈设置
        stopProfitText := Trim(stopProfitEdit.Text)
        if (stopProfitText != "" && stopProfitText != "选填") {
            stopProfit := Round(stopProfitText + 0, 2)
            if (stopProfit > 0) {
                UserConfig["StopProfit"] := stopProfit
                WriteLog("📝 止盈设置为: " . stopProfit, 2)
            } else {
                UserConfig["StopProfit"] := 0
            }
        } else {
            UserConfig["StopProfit"] := 0
        }
        
        ; 读取止损设置
        stopLossText := Trim(stopLossEdit.Text)
        if (stopLossText != "" && stopLossText != "选填") {
            stopLoss := Round(stopLossText + 0, 2)
            if (stopLoss > 0) {
                UserConfig["StopLoss"] := stopLoss
                WriteLog("📝 止损设置为: " . stopLoss, 2)
            } else {
                UserConfig["StopLoss"] := 0
            }
        } else {
            UserConfig["StopLoss"] := 0
        }
        
        ; 禁用输入框
        stopProfitEdit.Enabled := false
        stopLossEdit.Enabled := false
        
        g_Initialized := false
        ScriptPaused := false
        StopBetting := false
        ResetTimeDetection()
        
        btnBetToggle.Text := "停止下注"
        btnBetToggle.SetFont("cWhite", "微软雅黑")
        btnBetToggle.BackColor := "Red"
        
        if IsGrabEnabled {
            statusText.Text := "▶️ 下注运行中 | ▶️ 抓奖运行中"
        } else {
            statusText.Text := "▶️ 下注运行中 | ⏸️ 抓奖已停止"
        }
        statusText.SetFont("cGreen")
        
        WriteLog("▶️ 用户开启下注", 2)
        WriteLog("📊 本金: " . UserConfig["InitBalance"] . " | 止盈: " . UserConfig["StopProfit"] . " | 止损: " . UserConfig["StopLoss"], 2)
        
        ToolTip "🚀 下注已开启`n本金: " . UserConfig["InitBalance"] . " 元"
        SetTimer(ToolTipClear, -3000)
        
    } else {
        ; ★★★ 停止下注 ★★★
        stopProfitEdit.Enabled := true
        stopLossEdit.Enabled := true
        
        ScriptPaused := true
        btnBetToggle.Text := "开启下注"
        btnBetToggle.SetFont("cWhite", "微软雅黑")
        btnBetToggle.BackColor := "Green"
        
        ; ★★★ 取消本金复选框的勾选 ★★★
        chkBalance.Value := 0
        IsBalanceSet := false
        OriginalBalance := 0
        
        if IsGrabEnabled {
            statusText.Text := "⏸️ 下注已暂停 | ▶️ 抓奖运行中"
        } else {
            statusText.Text := "⏸️ 下注已暂停 | ⏸️ 抓奖已停止"
        }
        statusText.SetFont("cRed")
        
        WriteLog("⏸️ 用户停止下注，本金已清除", 2)
        ToolTip "⏸️ 下注已暂停，本金已清除"
        SetTimer(ToolTipClear, -3000)
    }
}

; ============================================================
; ★★★ 本金复选框点击事件 ★★★
; ============================================================
OnBalanceCheck(*) {
    global chkBalance, IsBalanceSet, btnBetToggle, statusText, UserConfig, OriginalBalance, IsGrabEnabled
    global IsBalanceFirstTime
    
    if !IsGrabEnabled {
        chkBalance.Value := 0
        CustomMsgBox("提示", "❌ 请先开启抓奖！")
        return
    }
    
    isChecked := chkBalance.Value
    
    if isChecked {
        ; ★★★ 勾选了 → 执行识别余额（第一次立即写入） ★★★
        IsBalanceFirstTime := true
        SetBalance()
    } else {
        ; ★★★ 取消勾选 → 清除本金，停止定时写入 ★★★
        IsBalanceSet := false
        UserConfig["InitBalance"] := 0
        OriginalBalance := 0
        IsBalanceFirstTime := true
        btnBetToggle.Enabled := false
        btnBetToggle.SetFont("cGray", "微软雅黑")
        btnBetToggle.BackColor := "Green"
        statusText.Text := "⏸️ 本金已取消，请重新勾选"
        statusText.SetFont("cRed")
        WriteLog("❌ 本金已取消，定时写入已停止", 2)
        ToolTip "❌ 本金已取消"
        SetTimer(ToolTipClear, -3000)
    }
}

; ============================================================
; ★★★ 本金按钮功能 - 调用 get_balance.py 识别余额 ★★★
; ============================================================
SetBalance() {
    global BetAmountResultFile, UserConfig, btnBetToggle, statusText, chkBalance, IsBalanceSet, OriginalBalance
    global IsBalanceFirstTime
    
    WriteLog("💰 点击本金按钮，开始识别余额...", 2)
    
    ; ★★★ 改为调用 py ★★★
    pythonPath := "py -3.11"
    scriptPath := "C:\Users\Administrator\Desktop\zhuajiang\get_balance.py"
    
    if !FileExist(scriptPath) {
        CustomMsgBox("提示", "❌ get_balance.py 不存在！`n`n路径: " . scriptPath)
        return
    }
    
    if FileExist(BetAmountResultFile) {
        try FileDelete(BetAmountResultFile)
    }
    
    ToolTip "📷 正在识别余额，请稍候..."
    Sleep 500
    
    try {
        RunWait(pythonPath . " " . scriptPath, , "Hide")
        WriteLog("✅ 余额识别 .py 执行完成", 2)
    } catch as e {
        WriteLog("❌ 余额识别运行失败: " . e.Message, 1)
        ToolTip "❌ 余额识别失败！"
        SetTimer(ToolTipClear, -3000)
        CustomMsgBox("提示", "❌ 余额识别运行失败！`n`n" . e.Message)
        return
    }
    
    waitCount := 0
    while !FileExist(BetAmountResultFile) && waitCount < 25 {
        Sleep(200)
        waitCount += 1
    }
    
    if !FileExist(BetAmountResultFile) {
        CustomMsgBox("提示", "❌ 余额识别超时！")
        ToolTip "❌ 余额识别超时！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    
    content := ""
    initBalance := 0
    try {
        content := FileRead(BetAmountResultFile)
        content := Trim(content)
        WriteLog("📄 余额文件内容: [" . content . "]", 2)
        
        if RegExMatch(content, "(\d+\.?\d*)", &match) {
            initBalance := Round(match[1] + 0, 2)
            WriteLog("📊 识别到余额: " . initBalance, 2)
        }
    } catch as e {
        WriteLog("❌ 读取余额文件失败: " . e.Message, 1)
    }
    
    if (content == "" || initBalance < 0) {
        CustomMsgBox("提示", "❌ 未能识别到有效余额！`n`n识别结果: " . content)
        ToolTip "❌ 未能识别到有效余额！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    
    UserConfig["InitBalance"] := initBalance
    OriginalBalance := initBalance
    IsBalanceSet := true
    WriteLog("📝 本金设置为: " . initBalance . "，本金按钮已标记", 2)
    
    WriteBalanceToExcel(initBalance)
    
    IsBalanceFirstTime := false
    
    chkBalance.Value := 1
    
    btnBetToggle.Enabled := true
    btnBetToggle.SetFont("cWhite", "微软雅黑")
    btnBetToggle.BackColor := "Green"
    
    statusText.Text := "💰 本金已设置: " . initBalance . " 元 | 可以开启下注"
    statusText.SetFont("cGreen")
    
    ToolTip "💰 本金已设置: " . initBalance . " 元"
    SetTimer(ToolTipClear, -3000)
    
    CustomMsgBox("本金设置", "✅ 本金设置成功！`n`n当前本金: " . initBalance . " 元`n`n现在可以点击「开启下注」了。")
}

; ============================================================
; ★★★ 定时读取余额并写入Excel A列（使用COM对象） ★★★
; ============================================================
; ============================================================
; ★★★ 定时读取余额并写入Excel A列（写入到当前单元格的上一行） ★★★
; ============================================================
ReadBalanceAndWriteToExcel() {
    global BetAmountResultFile, UserConfig, IsBalanceSet, IsBalanceFirstTime
    
    if !IsBalanceSet {
        WriteLog("⏸️ 本金未设置，跳过余额读取", 2)
        return
    }
    
    if IsBalanceFirstTime {
        WriteLog("⏸️ 第一次勾选，已立即写入，跳过定时写入", 2)
        return
    }
    
    WriteLog("📊 定时读取余额并写入A列（当前单元格上一行）...", 2)
    
    ; ★★★ 改为调用 py ★★★
    pythonPath := "py -3.11"
    scriptPath := "C:\Users\Administrator\Desktop\zhuajiang\get_balance.py"
    
    if !FileExist(scriptPath) {
        WriteLog("❌ get_balance.py 不存在", 1)
        return
    }
    
    if FileExist(BetAmountResultFile) {
        try FileDelete(BetAmountResultFile)
    }
    
    try {
        RunWait(pythonPath . " " . scriptPath, , "Hide")
        WriteLog("✅ 余额识别 .py 执行完成", 2)
    } catch as e {
        WriteLog("❌ 余额识别运行失败: " . e.Message, 1)
        return
    }
    
    waitCount := 0
    while !FileExist(BetAmountResultFile) && waitCount < 25 {
        Sleep(200)
        waitCount += 1
    }
    
    if !FileExist(BetAmountResultFile) {
        WriteLog("❌ 余额识别超时", 1)
        return
    }
    
    currentBalance := 0
    try {
        content := FileRead(BetAmountResultFile)
        content := Trim(content)
        WriteLog("📄 余额文件内容: [" . content . "]", 2)
        
        if RegExMatch(content, "(\d+\.?\d*)", &match) {
            currentBalance := Round(match[1] + 0, 2)
            WriteLog("📊 识别到余额: " . currentBalance, 2)
        }
    } catch as e {
        WriteLog("❌ 读取余额文件失败: " . e.Message, 1)
        return
    }
    
    if (currentBalance < 0) {
        WriteLog("⚠️ 识别到负数余额，跳过写入", 1)
        return
    }
    
    ; ★★★ 使用COM对象写入Excel A列（当前单元格上一行） ★★★
    try {
        oExcel := ComObjActive("Excel.Application")
    } catch {
        WriteLog("❌ 未检测到正在运行的Excel", 1)
        ToolTip "❌ 未检测到正在运行的Excel！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    
    try {
        oSheet := oExcel.ActiveSheet
        
        ; ★★★ 获取当前选中单元格的行号 ★★★
        currentRow := oExcel.ActiveCell.Row
        
        ; ★★★ 写入到上一行 ★★★
        targetRow := currentRow - 1
        
        ; ★★★ 如果上一行小于1，则写入到第1行 ★★★
        if (targetRow < 1) {
            targetRow := 1
            WriteLog("⚠️ 当前在第1行，写入到第1行", 2)
        }
        
        ; ★★★ 写入A列 ★★★
        oSheet.Cells(targetRow, 1).Value := currentBalance
        
        WriteLog("✅ 余额已写入A列: " . currentBalance . " (当前行: " . currentRow . " → 写入行: " . targetRow . ")", 2)
        ToolTip "💰 余额已更新: " . currentBalance . " 元 (行: " . targetRow . ")"
        SetTimer(ToolTipClear, -2000)
        
    } catch as e {
        WriteLog("❌ 写入余额到Excel失败: " . e.Message, 1)
        ToolTip "❌ 写入失败！"
        SetTimer(ToolTipClear, -3000)
    }
}

; ============================================================
; ★★★ 写入余额到Excel A列（使用COM对象） ★★★
; ============================================================
; ============================================================
; ★★★ 写入余额到Excel A列（写入到当前单元格的上一行） ★★★
; ============================================================
WriteBalanceToExcel(balance) {
    WriteLog("📝 写入余额到Excel A列（当前单元格上一行）: " . balance, 2)
    
    try {
        ; ★★★ 连接Excel ★★★
        oExcel := ComObjActive("Excel.Application")
    } catch {
        WriteLog("❌ 未检测到正在运行的Excel", 1)
        ToolTip "❌ 未检测到正在运行的Excel！"
        SetTimer(ToolTipClear, -3000)
        return false
    }
    
    try {
        oSheet := oExcel.ActiveSheet
        
        ; ★★★ 获取当前选中单元格的行号 ★★★
        currentRow := oExcel.ActiveCell.Row
        
        ; ★★★ 写入到上一行 ★★★
        targetRow := currentRow - 1
        
        ; ★★★ 如果上一行小于1，则写入到第1行 ★★★
        if (targetRow < 1) {
            targetRow := 1
            WriteLog("⚠️ 当前在第1行，写入到第1行", 2)
        }
        
        ; ★★★ 写入A列 ★★★
        oSheet.Cells(targetRow, 1).Value := balance
        
        WriteLog("✅ 余额已写入A列: " . balance . " (当前行: " . currentRow . " → 写入行: " . targetRow . ")", 2)
        ToolTip "💰 本金已写入: " . balance . " 元 (行: " . targetRow . ")"
        SetTimer(ToolTipClear, -2000)
        return true
        
    } catch as e {
        WriteLog("❌ 写入余额到Excel失败: " . e.Message, 1)
        ToolTip "❌ 写入失败！"
        SetTimer(ToolTipClear, -3000)
        return false
    }
}

; ============================================================
; ★★★ 开启/停止抓奖 ★★★
; ============================================================
ToggleGrab(*) {
    global IsGrabEnabled, IsAuthorized, GrabLastRunSec, ScriptPaused, statusText
    global stopProfitEdit, stopLossEdit, SettingsGui
    
    if !IsAuthorized {
        statusText.Text := "❌ 请先验证卡密！"
        statusText.SetFont("cRed")
        return
    }
    
    if !WinExist(WinProcess) {
        CustomMsgBox("提示", "未找到模拟器窗口，请先打开雷电模拟器！")
        return
    }
    
    if !IsGrabEnabled {
        ; ★★★ 开启抓奖 ★★★
        IsGrabEnabled := true
        GrabLastRunSec := -1
        
        ; ★★★ 修改抓奖按钮 ★★★
        try {
            if IsObject(SettingsGui.btnGrabToggle) {
                SettingsGui.btnGrabToggle.Text := "停止抓奖"
                SettingsGui.btnGrabToggle.SetFont("cWhite", "微软雅黑")
                SettingsGui.btnGrabToggle.BackColor := "Red"
            }
        } catch {
            WriteLog("⚠️ 更新抓奖按钮失败", 1)
        }
        
        ; ★★★ 尝试启用本金复选框（用户端才有） ★★★
        try {
            if IsObject(SettingsGui.chkBalance) {
                SettingsGui.chkBalance.Enabled := true
            }
        } catch {
        }
        
        ; ★★★ 尝试启用开启下注按钮（用户端才有） ★★★
        try {
            if IsObject(SettingsGui.btnBetToggle) {
                SettingsGui.btnBetToggle.Enabled := true
                SettingsGui.btnBetToggle.SetFont("cWhite", "微软雅黑")
                SettingsGui.btnBetToggle.BackColor := "Green"
            }
        } catch {
        }
        
        ; ★★★ 主播端：只显示抓奖状态 ★★★
        statusText.Text := "▶️ 抓奖运行中"
        statusText.SetFont("cGreen")
        WriteLog("▶️ 用户开启抓奖", 2)
        WriteLog("📋 抓奖流程: 53/23秒退出 → 57/27秒进入 → 运行Python脚本 → 写入Excel", 2)
        
        ToolTip "🚀 抓奖已开启`n53/23秒 → 退出`n57/27秒 → 进入 → 运行Python脚本"
        SetTimer(ToolTipClear, -4000)
    } else {
        ; ★★★ 停止抓奖 ★★★
        IsGrabEnabled := false
        GrabLastRunSec := -1
        
        ; ★★★ 修改抓奖按钮 ★★★
        try {
            if IsObject(SettingsGui.btnGrabToggle) {
                SettingsGui.btnGrabToggle.Text := "开启抓奖"
                SettingsGui.btnGrabToggle.SetFont("cWhite", "微软雅黑")
                SettingsGui.btnGrabToggle.BackColor := "Green"
            }
        } catch {
            WriteLog("⚠️ 更新抓奖按钮失败", 1)
        }
        
        ; ★★★ 尝试禁用本金复选框（用户端才有） ★★★
        try {
            if IsObject(SettingsGui.chkBalance) {
                SettingsGui.chkBalance.Enabled := false
                SettingsGui.chkBalance.Value := 0
            }
        } catch {
        }
        
        ; ★★★ 尝试禁用开启下注按钮（用户端才有） ★★★
        try {
            if IsObject(SettingsGui.btnBetToggle) {
                SettingsGui.btnBetToggle.Enabled := false
                SettingsGui.btnBetToggle.SetFont("cGray", "微软雅黑")
                SettingsGui.btnBetToggle.BackColor := "Green"
                SettingsGui.btnBetToggle.Text := "开启下注"
            }
        } catch {
        }
        
        IsBalanceSet := false
        OriginalBalance := 0
        
        if !ScriptPaused {
            ScriptPaused := true
            StopBetting := true
            stopProfitEdit.Enabled := true
            stopLossEdit.Enabled := true
            WriteLog("⏸️ 抓奖已停止，下注自动暂停，本金已清除", 2)
        }
        
        ; ★★★ 主播端：只显示抓奖状态 ★★★
        statusText.Text := "⏸️ 抓奖已停止"
        statusText.SetFont("cRed")
        WriteLog("⏸️ 用户停止抓奖", 2)
        ToolTip "⏸️ 抓奖已停止，本金已清除"
        SetTimer(ToolTipClear, -2000)
    }
}

; ============================================================
; ★★★ 退出脚本 ★★★
; ============================================================
ExitScript(*) {
    WriteLog("🛑 通过设置界面退出脚本", 2)
    WriteLog("=== 脚本结束 ===", 2)
    ToolTip "正在退出脚本..."
    Sleep 500
    ToolTip
    try SettingsGui.Destroy()
    ExitApp()
}

; ============================================================
; ★★★ 获取J列时间数据 ★★★
; ============================================================
GetJColumnTime() {
    global IsAuthorized
    if !IsAuthorized {
        return ""
    }
    
    WriteLog("📊 开始获取J列时间数据...", 3)
    excelHWND := FindExcelWindow()
    if !excelHWND {
        WriteLog("❌ 无法获取J列数据：未找到Excel窗口", 0)
        return ""
    }
    
    oldClipboard := A_Clipboard
    WinActivate(excelHWND)
    Sleep 300
    
    Send "{Ctrl down}{Home}{Ctrl up}"
    Sleep 200
    Loop 9 {
        Send "{Right}"
        Sleep 50
    }
    Sleep 200
    
    ; ★★★ 删掉了 Ctrl+Down ★★★
    
    Send "^c"
    Sleep 300
    content := Trim(A_Clipboard)
    
    if (content == "") {
        Send "{Up}"
        Sleep 200
        Send "^c"
        Sleep 200
        content := Trim(A_Clipboard)
    }
    
    WriteLog("📊 J列时间数据: " . (content != "" ? content : "(空)"), 3)
    A_Clipboard := oldClipboard
    return content
}

; ============================================================
; ★★★ 定位到B列最新数据单元格 ★★★
; ============================================================
GoToBCellPrevious() {
    WriteLog("📍 定位到B列最新数据的上一个单元格...", 2)
    excelHWND := FindExcelWindow()
    if !excelHWND {
        WriteLog("❌ 未找到Excel窗口", 0)
        return false
    }
    
    WinActivate(excelHWND)
    Sleep 300
    
    Send "{Ctrl down}{Home}{Ctrl up}"
    Sleep 200
    Send "{Right}"
    Sleep 200
    Send "{Ctrl down}{Down}{Ctrl up}"
    Sleep 500
    Send "{Up}"
    Sleep 200
    
    WriteLog("✅ 已定位到B列最新数据的上一行", 2)
    return true
}

; ============================================================
; ★★★ 检测重复下注 ★★★
; ============================================================
CheckDuplicateBet() {
    global LastJTime, SameTimeCount, MaxSameTimeCount, ScriptPaused, StopBetting
    global btnBetToggle, statusText, stopProfitEdit, stopLossEdit, IsGrabEnabled
    
    jTime := GetJColumnTime()
    
    if (jTime == "") {
        WriteLog("📊 J列为空，正常下注", 2)
        LastJTime := ""
        SameTimeCount := 0
        return true
    }
    
    if (LastJTime == "") {
        LastJTime := jTime
        SameTimeCount := 1
        WriteLog("📊 首次记录J列时间: " . jTime, 2)
        return true
    }
    
    if (jTime == LastJTime) {
        SameTimeCount += 1
        WriteLog("⚠️ J列时间相同 (" . SameTimeCount . "/" . MaxSameTimeCount . "): " . jTime, 1)
        
        if (SameTimeCount >= MaxSameTimeCount) {
            WriteLog("🚨🚨🚨 连续" . MaxSameTimeCount . "次检测到相同时间，判定为重复下注！", 0)
            GoToBCellPrevious()
            Sleep 500
            WriteLog("⏸️ 脚本已暂停（重复下注检测触发）", 0)
            
            ScriptPaused := true
            StopBetting := true
            
            ; ★★★ 更新按钮文字 ★★★
            btnBetToggle.Text := "开启下注"
            btnBetToggle.SetFont("cWhite", "微软雅黑")
            btnBetToggle.BackColor := "Green"
            stopProfitEdit.Enabled := true
            stopLossEdit.Enabled := true
            if IsGrabEnabled {
                statusText.Text := "⏸️ 下注已暂停 | ▶️ 抓奖运行中"
            } else {
                statusText.Text := "⏸️ 下注已暂停 | ⏸️ 抓奖已停止"
            }
            statusText.SetFont("cRed")
            
            ToolTip "🚨 重复下注检测触发！`n连续" . MaxSameTimeCount . "次相同时间: " . jTime . "`n已定位到B列最新数据的上一行`n脚本已暂停"
            SetTimer(ToolTipClear, -5000)
            
            CustomMsgBox("重复下注检测", "🚨 重复下注检测触发！`n`n连续" . MaxSameTimeCount . "次检测到相同时间: " . jTime . "`n`n已定位到B列最新数据的上一行`n脚本已自动暂停，请检查Excel数据。")
            return false
        }
        return true
    } else {
        WriteLog("✅ J列时间已更新: " . jTime . " (之前: " . LastJTime . ")", 2)
        LastJTime := jTime
        SameTimeCount := 1
        return true
    }
}

; ============================================================
; ★★★ 执行完整下注流程 ★★★
; ============================================================
ExecuteFullBet(betType, betAmount, cellContent) {
    global StopBetting, ScriptPaused, IsAuthorized, UserConfig, ButtonPos, IsBetting
    
    if !IsAuthorized or StopBetting or ScriptPaused {
        return
    }
    
    ; ★★★ 加锁：防止重复下注 ★★★
    if IsBetting {
        WriteLog("⏸️ 正在下注中，跳过本次触发", 2)
        return
    }
    IsBetting := true
    
    WriteLog("🔄 开始下注 - " . betType . " " . betAmount, 2)
    
    if !WinExist(WinProcess) {
        WriteLog("❌ 未找到模拟器", 0)
        ToolTip "未找到模拟器"
        SetTimer(ToolTipClear, -2000)
        IsBetting := false
        return
    }
    
    hwnd := WinExist(WinProcess)
    if WinGetMinMax(hwnd) == -1 {
        WinRestore(hwnd)
        Sleep 500
    }
    
    WinActivate(WinProcess)
    Sleep UserConfig["BetDelay"]
    
    rect := GetEmulatorRect()
    if rect["width"] == 0 {
        WriteLog("❌ 无法获取窗口坐标", 0)
        IsBetting := false
        return
    }
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    buttonName := (betType == "庄") ? "zhuang" : "xian"
    pos := ButtonPos[buttonName]
    ClickRelative(pos[1], pos[2], "选择" . betType)
    Sleep UserConfig["ClickDelay"]
    WriteLog("✅ 步骤1完成：已点击" . betType . "按钮", 2)
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    pos := ButtonPos["amount"]
    WriteLog("📝 步骤2：开始输入金额 " . betAmount, 2)
    
    Loop 4 {
        ClickRelative(pos[1], pos[2], "点击金额框")
        Sleep 200
        if ScriptPaused or StopBetting {
            WriteLog("⏸️ 用户暂停，停止下注", 2)
            IsBetting := false
            return
        }
    }
    WriteLog("🖱️ 已点击金额框4次", 3)
    
    Sleep 300
    Send "^a"
    Sleep 200
    WriteLog("⌨️ 已发送 Ctrl+A (全选)", 3)
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    Loop 5 {
        Send "{Backspace}"
        Sleep 50
        if ScriptPaused or StopBetting {
            WriteLog("⏸️ 用户暂停，停止下注", 2)
            IsBetting := false
            return
        }
    }
    WriteLog("⌨️ 已发送 Backspace x5 (清空)", 3)
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    ClickRelative(pos[1], pos[2], "再次点击金额框")
    Sleep 200
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    WriteLog("⌨️ 开始逐字符输入: " . betAmount, 3)
    for index, char in StrSplit(betAmount) {
        Send char
        Sleep 80
        if ScriptPaused or StopBetting {
            WriteLog("⏸️ 用户暂停，停止下注", 2)
            IsBetting := false
            return
        }
    }
    WriteLog("✅ 金额输入完成: " . betAmount, 2)
    
    Sleep 300
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    Send "{Enter}"
    Sleep 300
    WriteLog("⌨️ 已发送 Enter (确认金额)", 3)
    
    Sleep 500
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    pos := ButtonPos["confirm"]
    ClickRelative(pos[1], pos[2], "确认下注")
    Sleep 500
    WriteLog("🖱️ 已点击确认按钮", 3)
    
    if ScriptPaused or StopBetting {
        WriteLog("⏸️ 用户暂停，停止下注", 2)
        IsBetting := false
        return
    }
    
    WriteLog("✅✅✅ 下注完成 - " . betType . " " . betAmount, 2)
    ToolTip "✅ 下注完成: " . betAmount
    SetTimer(ToolTipClear, -2000)
    
    WriteLog("🔄 返回Excel并定位到B列...", 2)
    excelHWND := FindExcelWindow()
    if excelHWND {
        WinActivate(excelHWND)
        Sleep 300
        Send "{Ctrl down}{Home}{Ctrl up}"
        Sleep 200
        Send "{Right}"
        Sleep 200
        Send "{Ctrl down}{Down}{Ctrl up}"
        Sleep 500
        Send "{Up}"
        Sleep 200
        WriteLog("✅ 已定位到Excel B列最新数据", 2)
    } else {
        WriteLog("⚠️ 未找到Excel窗口，无法定位B列", 1)
    }
    
       WriteLog("🔍 所有步骤完成，检测是否需要额外点击...", 2)
       SetTimer(取消充值, -10)
    
    ; ★★★ 下注完成，解锁 ★★★
    IsBetting := false
    WriteLog("✅ 下注流程结束，解锁，等待下一轮抓奖", 2)
}

DoBetWithCheck(betType, betAmount, cellContent) {
    ExecuteFullBet(betType, betAmount, cellContent)
}

; ============================================================
; 【下注流程】
; ============================================================
FindExcelWindow() {
    WriteLog("🔍 查找Excel窗口...", 3)
    if WinExist("ahk_exe excel.exe") {
        return WinExist("ahk_exe excel.exe")
    }
    if WinExist("ahk_class XLMAIN") {
        return WinExist("ahk_class XLMAIN")
    }
    for hwnd in WinGetList() {
        winTitle := WinGetTitle(hwnd)
        if InStr(winTitle, "Excel") or InStr(winTitle, "工作") or InStr(winTitle, "Book") {
            return hwnd
        }
    }
    WriteLog("❌ 未找到Excel窗口", 0)
    return 0
}

GetLastAColumnValue() {
    global IsAuthorized
    if !IsAuthorized {
        WriteLog("⚠️ 未授权，跳过读取A列值", 1)
        return 0
    }
    
    WriteLog("📊 开始获取A列最后一个值...", 3)
    excelHWND := FindExcelWindow()
    if !excelHWND {
        WriteLog("❌ 无法获取A列值：未找到Excel窗口", 0)
        return 0
    }
    
    oldClipboard := A_Clipboard
    WinActivate(excelHWND)
    Sleep 500
    
    ; 定位到A列
    Send "{Ctrl down}{Home}{Ctrl up}"
    Sleep 300
    Send "{Home}"
    Sleep 200
    
    ; 跳到A列最后一个有数据的单元格
    Send "{Ctrl down}{Down}{Ctrl up}"
    Sleep 500
    
    ; 如果当前单元格为空，向上找
    Send "^c"
    Sleep 300
    content := Trim(A_Clipboard)
    if (content == "") {
        Loop 5 {
            Send "{Up}"
            Sleep 200
            Send "^c"
            Sleep 200
            content := Trim(A_Clipboard)
            if (content != "") {
                WriteLog("📊 向上找到第" . A_Index . "行有数据", 3)
                break
            }
        }
        if (content == "") {
            WriteLog("❌ A列未找到有效数据", 0)
            A_Clipboard := oldClipboard
            return 0
        }
    }
    
    WriteLog("📊 A列数值: " . content, 3)
    A_Clipboard := oldClipboard
    
    if RegExMatch(content, "(\d+\.?\d*)", &match) {
        return Round(match[1] + 0, 2)
    }
    return 0
}

GoToExcelCell() {
    global IsAuthorized
    if !IsAuthorized {
        return
    }
    Send "{Ctrl down}{Home}{Ctrl up}"
    Sleep 200
    Send "{Right}"
    Sleep 200
    Send "{Ctrl down}{Down}{Ctrl up}"
    Sleep 300
    Send "{Up}"
    Sleep 200
    Send "^c"
    Sleep 200
    cellContent := Trim(A_Clipboard)
    if (cellContent == "") {
        Send "{Up}"
        Sleep 200
        Send "^c"
        Sleep 200
        cellContent := Trim(A_Clipboard)
    }
}

ExecuteBet() {
    global StopBetting, ScriptPaused, IsAuthorized
    
    if !IsAuthorized or StopBetting or ScriptPaused {
        return
    }
    
    WriteLog("🔄 执行下注流程（读取Excel）", 3)
    
    if !CheckDuplicateBet() {
        return
    }
    
    excelHWND := FindExcelWindow()
    if !excelHWND {
        WriteLog("❌ 未找到Excel窗口", 0)
        ToolTip "未找到Excel窗口"
        SetTimer(ToolTipClear, -2000)
        return
    }
    WinActivate(excelHWND)
    Sleep 500
    GoToExcelCell()
    Send "^c"
    Sleep 200
    cellContent := Trim(A_Clipboard)
    if (cellContent == "") {
        WriteLog("❌ B列为空", 0)
        ToolTip "B列没有有效数据"
        SetTimer(ToolTipClear, -2000)
        return
    }
    WriteLog("📝 数据: " . cellContent, 3)
    
    if InStr(cellContent, "庄") {
        betType := "庄"
    } else if InStr(cellContent, "闲") {
        betType := "闲"
    } else if InStr(cellContent, "和") {
        betType := "和"
    } else {
        WriteLog("❌ 无效下注类型: " . cellContent, 0)
        return
    }
    
    match := RegExMatch(cellContent, "\d+", &matchObj)
    if !match || matchObj[0] <= 0 {
        WriteLog("❌ 无效金额: " . cellContent, 0)
        return
    }
    betAmount := matchObj[0]
    
    DoBetWithCheck(betType, betAmount, cellContent)
}

; ============================================================
; ★★★ 抓奖定时任务 ★★★
; ============================================================
CheckTimers() {
    global IsAuthorized, ScriptPaused, IsGrabEnabled, GrabLastRunSec, BJLDetected, BJLEnterDetected
    global LastBalanceReadSec, LastBetTriggerSec
    
    if !IsAuthorized {
        return
    }
    
    currentSec := Integer(A_Sec)
    
    if IsGrabEnabled {
        
        ; ★★★ 3秒/33秒 读取余额并写入A列 ★★★
        if ((currentSec == 3 || currentSec == 33) && currentSec != LastBalanceReadSec) {
            LastBalanceReadSec := currentSec
            WriteLog("💰 触发余额读取 (秒: " . currentSec . ")", 2)
            SetTimer(ReadBalanceAndWriteToExcel, -10)
        }
        
        ; ★★★ 6秒/36秒 触发下注 ★★★
        if (currentSec == 6 || currentSec == 36) {
            if (currentSec != LastBetTriggerSec) {
                LastBetTriggerSec := currentSec
                WriteLog("⏰ 触发定时下注 (秒: " . currentSec . ")", 2)
                SetTimer(MainTask, -10)
            }
        }
        
        ; ★★★ 53秒/23秒 执行退出（直接点击，不检测） ★★★
        if ((currentSec == 53 || currentSec == 23) && currentSec != GrabLastRunSec) {
            GrabLastRunSec := currentSec
            WriteLog("⏰ 触发抓奖-退出 (秒: " . currentSec . ")", 2)
            SetTimer(DoGrabExit, -10)
        }
        
        ; ★★★ 56秒/26秒 执行进入（直接点击，不检测） ★★★
        if ((currentSec == 56 || currentSec == 26) && currentSec != GrabLastRunSec) {
            GrabLastRunSec := currentSec
            WriteLog("⏰ 触发抓奖-进入 (秒: " . currentSec . ")", 2)
            SetTimer(DoGrabEnter, -10)
        }
    }
}

MainTask() {
    global StopBetting, ScriptPaused, IsAuthorized, UserConfig, g_Initialized
    global btnBetToggle, statusText, stopProfitEdit, stopLossEdit, IsGrabEnabled, SettingsGui, BetAmountResultFile
    global OriginalBalance
    
    if !IsAuthorized or ScriptPaused {
        return
    }
    
    if !g_Initialized {
        WriteLog("📝 首次执行：标记已初始化", 2)
        g_Initialized := true
    }
    
    WriteLog("🔄 执行主任务", 3)
    
    ; ★★★ 直接从 bet_amount_result.txt 读取当前余额 ★★★
    currentBalance := 0
    if FileExist(BetAmountResultFile) {
        try {
            content := FileRead(BetAmountResultFile)
            content := Trim(content)
            if RegExMatch(content, "(\d+\.?\d*)", &match) {
                currentBalance := Round(match[1] + 0, 2)
                WriteLog("📊 从文件读取当前余额: " . currentBalance, 2)
            }
        } catch {
            WriteLog("⚠️ 读取余额文件失败", 1)
        }
    }
    
    if (currentBalance <= 0) {
        WriteLog("⚠️ 无法读取余额（余额为0），继续下注流程", 1)
    }
    
    ; ★★★ 使用原始本金 ★★★
    initBalance := OriginalBalance
    if (initBalance <= 0) {
        WriteLog("❌ 未设置原始本金，跳过检查", 0)
        return
    }
    
    ; ★★★ 计算纯盈利 ★★★
    currentProfit := Round(currentBalance - initBalance, 2)
    stopProfit := Round(UserConfig["StopProfit"], 2)
    stopLoss := Round(UserConfig["StopLoss"], 2)
    
    WriteLog("📊 当前余额: " . currentBalance . " | 原始本金: " . initBalance . " | 纯盈利: " . currentProfit . " | 止盈: " . stopProfit . " | 止损: " . stopLoss, 2)
    ToolTip "【本金】" . initBalance . " | 【当前】" . currentBalance . " | 【盈亏】" . currentProfit
    Sleep 500
    
    ; ★★★ 止盈触发 ★★★
    if (stopProfit > 0 && currentProfit >= stopProfit) {
        WriteLog("🎯🎯🎯 触发止盈! (纯盈利: " . currentProfit . " >= " . stopProfit . ")", 1)
        
        StopBetting := true
        ScriptPaused := true
        WriteLog("⏸️ 脚本已暂停（止盈触发）", 1)

        stopProfitEdit.Enabled := true
        stopLossEdit.Enabled := true
        btnBetToggle.Text := "开启下注"
        btnBetToggle.SetFont("cWhite", "微软雅黑")
        btnBetToggle.BackColor := "Green"
        if IsGrabEnabled {
            statusText.Text := "⏸️ 下注已暂停 | ▶️ 抓奖运行中"
        } else {
            statusText.Text := "⏸️ 下注已暂停 | ⏸️ 抓奖已停止"
        }
        statusText.SetFont("cRed")
        
        msg := "🎯 止盈触发！`n`n当前余额: " . currentBalance . "`n本金: " . initBalance . "`n纯盈利: " . currentProfit . " 元`n止盈设定: " . stopProfit . " 元`n`n⏸️ 脚本已自动暂停"
        CustomMsgBox("止盈触发", msg)
        ToolTip "【止盈触发】盈利 " . currentProfit . " 元"
        SetTimer(ToolTipClear, -5000)
        return
    }
    
    ; ★★★ 止损触发 ★★★
    if (stopLoss > 0 && currentBalance <= stopLoss) {
        WriteLog("📉📉📉 触发止损! (当前余额: " . currentBalance . " <= " . stopLoss . ")", 1)
        
        StopBetting := true
        ScriptPaused := true
        WriteLog("⏸️ 脚本已暂停（止损触发）", 1)
        
        stopProfitEdit.Enabled := true
        stopLossEdit.Enabled := true
        btnBetToggle.Text := "开启下注"
        btnBetToggle.SetFont("cWhite", "微软雅黑")
        btnBetToggle.BackColor := "Green"
        if IsGrabEnabled {
            statusText.Text := "⏸️ 下注已暂停 | ▶️ 抓奖运行中"
        } else {
            statusText.Text := "⏸️ 下注已暂停 | ⏸️ 抓奖已停止"
        }
        statusText.SetFont("cRed")
        
        loss := Round(initBalance - currentBalance, 2)
        msg := "📉 止损触发！`n`n当前余额: " . currentBalance . "`n本金: " . initBalance . "`n当前亏损: " . loss . " 元`n止损设定: " . stopLoss . " 元`n`n⏸️ 脚本已自动暂停"
        CustomMsgBox("止损触发", msg)
        ToolTip "【止损触发】余额 " . currentBalance . " 元"
        SetTimer(ToolTipClear, -5000)
        return
    }
    
    if StopBetting {
        WriteLog("⏸️ 已止盈/止损，跳过", 1)
        return
    }
    
    WriteLog("📈 继续下注", 3)
    ExecuteBet()
}

ToolTipClear() {
    ToolTip
}

; ============================================================
; ★★★ 读取下注金额 ★★★
; ============================================================
ReadBetAmount() {
    global BetAmountResultFile, UserConfig, IsAuthorized, ScriptPaused
    
    if !IsAuthorized or ScriptPaused {
        WriteLog("⏸️ 脚本暂停或未授权，跳过读取金额", 2)
        return
    }
    
    WriteLog("📊 开始读取下注金额...", 2)
    
    pythonScript := "C:\Users\Administrator\Desktop\zhuajiang\ocr_bet_amount.py"
    if !FileExist(pythonScript) {
        WriteLog("❌ ocr_bet_amount.py 不存在", 1)
        return
    }
    
    try {
        RunWait(A_ComSpec . ' /c py -3.11 "' . pythonScript . '"', , "Hide")
        WriteLog("✅ 金额识别脚本执行完成", 2)
    } catch as e {
        WriteLog("❌ 金额识别脚本运行失败: " . e.Message, 1)
        return
    }
    
    if !FileExist(BetAmountResultFile) {
        WriteLog("❌ 金额结果文件不存在: " . BetAmountResultFile, 1)
        return
    }
    
    content := FileRead(BetAmountResultFile)
    content := Trim(content)
    WriteLog("📄 金额结果: " . content, 2)
    
    if (content = "" || content = "0") {
        WriteLog("⚠️ 金额识别为空，跳过写入", 1)
        return
    }
    
    excelHWND := FindExcelWindow()
    if !excelHWND {
        WriteLog("❌ 未找到Excel窗口", 1)
        ToolTip "❌ 未找到Excel窗口"
        SetTimer(ToolTipClear, -2000)
        return
    }
    
    WinActivate(excelHWND)
    Sleep 300
    
    Send "{Left}"
    Sleep 200
    Send "{Up}"
    Sleep 200
    
    Send content
    Sleep 200
    Send "{Enter}"
    Sleep 200
    Send "{Right}"
    Sleep 200
    
    WriteLog("✅ 金额已写入Excel: " . content, 2)
    ToolTip "✅ 金额已写入: " . content
    SetTimer(ToolTipClear, -2000)
}

; ============================================================
; ★★★ 下注完成后检测是否需要额外点击 ★★★
; ============================================================
; ============================================================
; ★★★ 取消充值检测 ★★★
; ============================================================
取消充值() {
    global IsAuthorized, ScriptPaused, StopBetting, btnBetToggle, statusText, IsGrabEnabled
    global stopProfitEdit, stopLossEdit, chkBalance, IsBalanceSet, OriginalBalance, SettingsGui
    
    if !IsAuthorized or ScriptPaused or StopBetting {
        WriteLog("⏸️ 脚本已暂停，跳过取消充值检测", 2)
        return
    }
    
    WriteLog("🔍 调用 取消充值.py 检测...", 2)
    
    ; ★★★ 指定 Python 和脚本路径 ★★★
    pythonPath := "py -3.11"
    scriptPath := "C:\Users\Administrator\Desktop\zhuajiang\check_bet_result.py"
    resultFile := "C:\Users\Administrator\Desktop\zhuajiang\bet_result.txt"
    
    ; 删除旧结果文件
    if FileExist(resultFile) {
        try {
            FileDelete(resultFile)
            WriteLog("✅ 已删除旧结果文件", 2)
        } catch {
            Sleep 500
            try FileDelete(resultFile)
        }
    }
    
    try {
        RunWait(pythonPath . " " . scriptPath, , "Hide")
        WriteLog("✅ 取消充值.py 执行完成", 2)
    } catch as e {
        WriteLog("❌ 取消充值检测失败: " . e.Message, 0)
        return
    }
    
    ; 等待结果文件生成
    Sleep 2000
    
    if FileExist(resultFile) {
        content := FileRead(resultFile)
        content := Trim(content)
        WriteLog("📤 返回: " . content, 2)
        
        if InStr(content, "MATCH:True") {
            WriteLog("✅ 匹配成功，执行取消充值点击", 2)
            rect := GetEmulatorRect()
            if rect["width"] > 0 {
                clickX := Round(rect["left"] + rect["width"] * 0.2816)
                clickY := Round(rect["top"] + rect["height"] * 0.5939)
                WriteLog("🖱️ 取消充值点击坐标: (" . clickX . ", " . clickY . ")", 2)
                Click(clickX, clickY)
                Sleep 300
                WriteLog("✅ 取消充值点击完成", 2)
                
                ; ★★★ 点击完成后，停止所有下注流程 ★★★
                WriteLog("🛑 取消充值点击完成，停止所有下注流程", 2)
                
                ; 停止下注
                StopBetting := true
                ScriptPaused := true
                
                ; 更新按钮状态
                btnBetToggle.Text := "开启下注"
                btnBetToggle.SetFont("cWhite", "微软雅黑")
                btnBetToggle.BackColor := "Green"
                
                ; 启用止盈止损输入框
                stopProfitEdit.Enabled := true
                stopLossEdit.Enabled := true
                
                ; 取消本金勾选
                chkBalance.Value := 0
                IsBalanceSet := false
                OriginalBalance := 0
                
                ; 更新状态文字
                if IsGrabEnabled {
                    statusText.Text := "⏸️ 下注已暂停（取消充值触发）| ▶️ 抓奖运行中"
                } else {
                    statusText.Text := "⏸️ 下注已暂停（取消充值触发）| ⏸️ 抓奖已停止"
                }
                statusText.SetFont("cRed")
                
                ; 日志记录
                WriteLog("⏸️ 脚本已暂停（取消充值触发停止下注）", 2)
                ToolTip "🛑 取消充值完成，下注已停止"
                SetTimer(ToolTipClear, -3000)
            }
        } else {
            WriteLog("⏸️ 匹配失败 (MATCH:False)，跳过取消充值点击", 2)
        }
    } else {
        WriteLog("❌ 结果文件未生成", 1)
    }
}

; ★★★ 执行退出操作（53秒/23秒触发） ★★★
DoGrabExit() {
    global IsGrabEnabled, GrabPos
    
    if !IsGrabEnabled {
        return
    }
    
    WriteLog("🔄 ===== 执行抓奖-退出操作 =====", 2)
    
    if !WinExist(WinProcess) {
        WriteLog("❌ 未找到模拟器窗口", 1)
        ToolTip "未找到模拟器窗口"
        SetTimer(ToolTipClear, -2000)
        return
    }
    
    hwnd := WinExist(WinProcess)
    if WinGetMinMax(hwnd) == -1 {
        WinRestore(hwnd)
        Sleep 500
    }
    WinActivate(WinProcess)
    Sleep 300
    
    rect := GetEmulatorRect()
    if rect["width"] == 0 {
        WriteLog("❌ 无法获取窗口坐标", 1)
        return
    }
    
    ; 步骤1：点击退出按钮
    WriteLog("🖱️ 步骤1: 点击退出按钮 [0.1222, 0.2570]", 2)
    pos := GrabPos["exit"]
    ClickRelative(pos[1], pos[2], "点击退出按钮")
    Sleep 500   ; ← 从 50 改成 200
    
    ; 步骤2：点击确认退出按钮
    WriteLog("🖱️ 步骤2: 点击确认退出按钮 [0.5944, 0.6392]", 2)
    pos := GrabPos["confirm"]
    ClickRelative(pos[1], pos[2], "点击确认退出按钮")
    Sleep 500   ; ← 从 50 改成 200
    
    WriteLog("✅ 抓奖-退出操作完成，等待4秒后进入", 2)
}

; ★★★ 执行进入操作（57/27秒触发） ★★★
DoGrabEnter() {
    global IsGrabEnabled, GrabPos
    
    if !IsGrabEnabled {
        return
    }
    
    WriteLog("🔄 ===== 执行抓奖-进入操作 =====", 2)
    
    hwnd := WinExist(WinProcess)
    if !hwnd {
        WriteLog("❌ 未找到模拟器窗口", 1)
        ToolTip "未找到模拟器窗口"
        SetTimer(ToolTipClear, -2000)
        return
    }
    
    if WinGetMinMax(hwnd) == -1 {
        WinRestore(hwnd)
        Sleep 500
    }
    WinActivate(hwnd)
    Sleep 300
    
    rect := GetEmulatorRect()
    if rect["width"] > 0 {
        pos := GrabPos["enter"]
        screenX := Round(rect["left"] + (rect["width"] * pos[1]))
        screenY := Round(rect["top"] + (rect["height"] * pos[2]))
        WriteLog("🖱️ 点击进入: (" . screenX . ", " . screenY . ")", 2)
        Click(screenX, screenY)
    } else {
        WriteLog("❌ 无法获取窗口坐标", 1)
        return
    }
    
    Sleep 500
    WriteLog("✅ 抓奖-进入操作完成", 2)
    
    ; ★★★ 点击进入后立即执行点数识别 ★★★
    WriteLog("📷 进入完成，立即启动点数识别...", 2)
    Sleep 500
    WriteLog("📷 开始执行OCR点数识别", 2)
    SetTimer(RunPythonScript, -10)  ; ★★★ 立即调用 ★★★
}

; ============================================================
; ★★★ 运行Python脚本 ★★★
; ============================================================
RunPythonScript() {
    global OcrWorkingDir, IsAuthorized, ScriptPaused
    global BetAmountResultFile, UserConfig, IsBalanceSet
    
    if !IsAuthorized {
        WriteLog("⏸️ 未授权，跳过运行", 3)
        return
    }
    
    WriteLog("📷 ===== 开始运行 ld_ocr_to_txt.py =====", 2)
    
    pythonPath := "py -3.11"
    scriptPath := "C:\Users\Administrator\Desktop\zhuajiang\ld_ocr_to_txt.py"
    
    WriteLog("📷 运行: " . scriptPath, 2)
    try {
        ; ★★★ 修复：第二个参数用 OcrWorkingDir，或者直接空着 ★★★
        RunWait(pythonPath . " " . scriptPath, , "Hide")
        WriteLog("✅ ld_ocr_to_txt.py 执行完成", 2)
    } catch as e {
        WriteLog("❌ 运行失败: " . e.Message, 0)
        ToolTip "❌ 运行失败！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    
    WriteLog("📷 ===== 运行结束 =====", 2)
    
    currentBalance := 0
    if FileExist(BetAmountResultFile) {
        try {
            content := FileRead(BetAmountResultFile)
            content := Trim(content)
            if RegExMatch(content, "(\d+\.?\d*)", &match) {
                currentBalance := Round(match[1] + 0, 2)
                WriteLog("📊 从文件读取余额: " . currentBalance, 2)
            }
        } catch as e {
            WriteLog("❌ 读取余额文件失败: " . e.Message, 1)
        }
    }
    
    resultFile := "C:\Users\Administrator\Desktop\zhuajiang\ocr_result.txt"
    
    if !FileExist(resultFile) {
        WriteLog("❌ 找不到结果文件: " . resultFile, 0)
        ToolTip "❌ 找不到结果文件！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    WriteLog("✅ 结果文件存在", 3)
    
    content := FileRead(resultFile)
    content := Trim(content)
    WriteLog("📄 文件内容: [" . content . "]", 2)
    
    if (content = "") {
        WriteLog("⚠️ 文件内容为空", 1)
        return
    }
    
    WriteLog("📷 步骤5: 连接Excel...", 3)
    try {
        oExcel := ComObjActive("Excel.Application")
    } catch {
        WriteLog("❌ 未检测到正在运行的Excel", 0)
        ToolTip "❌ 未检测到正在运行的Excel！"
        SetTimer(ToolTipClear, -3000)
        return
    }
    WriteLog("✅ 已连接到Excel", 3)
    
    try {
        WriteLog("📷 步骤6: 写入Excel...", 3)
        oSheet := oExcel.ActiveSheet
        arr := StrSplit(content, ",")
        
        WriteLog("📷 分割结果: 共" . arr.Length . "个元素", 3)
        for i, val in arr {
            WriteLog("📷   [" . i . "] = " . val, 3)
        }
        
        if (arr.Length >= 2) {
            currentRow := oExcel.ActiveCell.Row
            WriteLog("📷 当前行: " . currentRow, 3)
            
            oSheet.Cells(currentRow, 3).Value := arr[1]
            oSheet.Cells(currentRow, 4).Value := arr[2]
            WriteLog("📝 写入C列=" . arr[1] . ", D列=" . arr[2], 2)
            
            oSheet.Cells(currentRow + 1, 2).Select()
            WriteLog("✅✅✅ 写入Excel成功: C列=" . arr[1] . ", D列=" . arr[2], 2)
            
            if !ScriptPaused {
                WriteLog("📝 写入完成，等待定时器触发下注 (4秒/34秒)", 2)
            } else {
                WriteLog("⏸️ 下注已暂停，只写入Excel，不下注", 2)
            }
        } else {
            WriteLog("❌ 内容格式不对，没找到逗号分隔的两个数: " . content, 0)
        }
    } catch as e {
        WriteLog("❌ 写入Excel失败: " . e.Message, 0)
    }
    
    WriteLog("📷 ===== 处理完成 =====", 2)
}

; ============================================================
; ★★★ 本金输入框事件 ★★★
; ============================================================
InitBalanceFocus(*) {
    global initBalanceEdit
    if initBalanceEdit.Text == "必填" {
        initBalanceEdit.Text := ""
        initBalanceEdit.SetFont("cBlack")
    }
}

InitBalanceLoseFocus(*) {
    global initBalanceEdit
    if Trim(initBalanceEdit.Text) == "" {
        initBalanceEdit.Text := "必填"
        initBalanceEdit.SetFont("cGray")
    }
}

StopProfitFocus(*) {
    global stopProfitEdit
    if stopProfitEdit.Text == "选填" {
        stopProfitEdit.Text := ""
        stopProfitEdit.SetFont("cBlack")
    }
}

StopProfitLoseFocus(*) {
    global stopProfitEdit
    if Trim(stopProfitEdit.Text) == "" {
        stopProfitEdit.Text := "选填"
        stopProfitEdit.SetFont("cGray")
    }
}

StopLossFocus(*) {
    global stopLossEdit
    if stopLossEdit.Text == "选填" {
        stopLossEdit.Text := ""
        stopLossEdit.SetFont("cBlack")
    }
}

StopLossLoseFocus(*) {
    global stopLossEdit
    if Trim(stopLossEdit.Text) == "" {
        stopLossEdit.Text := "选填"
        stopLossEdit.SetFont("cGray")
    }
}

; ============================================================
; 【启动脚本】
; ============================================================
ClearLogsFolder()
InitLog()

fingerprint := CheckFingerprintConsistency()
if (fingerprint != "" && IsValidFingerprint(fingerprint)) {
    WriteLog("✅ 机器指纹检查通过: " . MaskFingerprint(fingerprint), 2)
} else {
    WriteLog("⚠️ 机器指纹异常，重新生成", 1)
    newID := GenerateStableFingerprint()
    SaveFingerprintToAll(newID)
    WriteLog("✅ 已重新生成指纹: " . MaskFingerprint(newID), 2)
}

WriteLog("脚本启动，等待验证...", 2)

ToolTip "🚀 正在启动脚本，请等待验证..."
Sleep 1500
ToolTip

if !VerifyKey() {
    while !IsAuthorized {
        Sleep 100
        if !WinExist("卡密验证系统") and !IsAuthorized {
            WriteLog("❌ 用户取消验证，脚本退出", 0)
            CustomMsgBox("提示", "验证取消，脚本退出")
            ExitApp()
        }
    }
}

Sleep 500
ScriptPaused := true
StopBetting := false
IsGrabEnabled := false
GrabLastRunSec := -1
ResetTimeDetection()

WriteLog("⏸️ 脚本就绪，等待用户操作", 2)
WriteLog("🎯 下注功能：点击「开启下注」启动", 2)
WriteLog("🎯 抓奖功能：点击「开启抓奖」启动", 2)
WriteLog("📋 抓奖流程: 53/23秒退出 → 57/27秒进入 → 运行Python脚本", 2)

; ★★★ 根据端口显示不同的 ToolTip ★★★
if (SubStr(CurrentUserKey, 1, 4) = "NKZB" || SubStr(CurrentUserKey, 1, 4) = "YKZB" || SubStr(CurrentUserKey, 1, 4) = "JKZB") {
    ; ★★★ 主播端：只显示抓奖 ★★★
    ToolTip "⏸️ 脚本已就绪`n抓奖：点击「开启抓奖」"
} else {
    ; ★★★ 用户端：显示下注 + 抓奖 ★★★
    ToolTip "⏸️ 脚本已就绪`n下注：点击「开启下注」`n抓奖：点击「开启抓奖」"
}
SetTimer(ToolTipClear, -5000)

SetTimer(CheckTimers, 500)

; ============================================================
; 【持久运行】
; ============================================================
PersistentLoop() {
    while true {
        Sleep 5000
    }
}

SetTimer(PersistentLoop, -1)

; ============================================================
; ★★★ 保存延迟到云端（管理卡专用） ★★★
; ============================================================
SaveBetDelayToCloud() {
    global betDelayEdit, UserConfig, CurrentUserKey
    value := betDelayEdit.Text
    if !IsNumber(value) || value <= 0 {
        MsgBox "⚠️ 请输入有效的数字（大于0）！"
        return
    }
    UserConfig["BetDelay"] := Integer(value)
    betDelayEdit.Text := UserConfig["BetDelay"]
    
    result := MsgBox("确定要将下注延迟保存到云端吗？`n`n当前值: " . value . " ms", "确认保存", "YesNo")
    if result = "Yes" {
        SyncDelayToCloudAll(CurrentUserKey, UserConfig["BetDelay"], UserConfig["ClickDelay"])
    }
}

SaveClickDelayToCloud() {
    global clickDelayEdit, UserConfig, CurrentUserKey
    value := clickDelayEdit.Text
    if !IsNumber(value) || value <= 0 {
        MsgBox "⚠️ 请输入有效的数字（大于0）！"
        return
    }
    UserConfig["ClickDelay"] := Integer(value)
    clickDelayEdit.Text := UserConfig["ClickDelay"]
    
    result := MsgBox("确定要将点击延迟保存到云端吗？`n`n当前值: " . value . " ms", "确认保存", "YesNo")
    if result = "Yes" {
        SyncDelayToCloudAll(CurrentUserKey, UserConfig["BetDelay"], UserConfig["ClickDelay"])
    }
}

; ============================================================
; ★★★ 延迟输入框失去焦点事件 ★★★
; ============================================================

OnBetDelayLoseFocus(*) {
    global betDelayEdit, UserConfig, CurrentUserKey
    value := betDelayEdit.Text
    if !IsNumber(value) || value <= 0 {
        MsgBox "⚠️ 请输入有效的数字（大于0）！"
        betDelayEdit.Text := UserConfig["BetDelay"]
        return
    }
    
    ; ★★★ 弹出确认框 ★★★
    result := MsgBox("确定要将下注延迟修改为 " . value . " ms 吗？`n`n点击「是」保存到云端，点击「否」取消修改。", "确认修改", "YesNo")
    if result = "Yes" {
        UserConfig["BetDelay"] := Integer(value)
        betDelayEdit.Text := UserConfig["BetDelay"]
        SyncDelayToCloudAll(CurrentUserKey, UserConfig["BetDelay"], UserConfig["ClickDelay"])
        ToolTip "✅ 下注延迟已同步到云端: " . value . " ms"
        SetTimer(ToolTipClear, -2000)
        WriteLog("📝 下注延迟已保存到云端: " . value, 2)
    } else {
        betDelayEdit.Text := UserConfig["BetDelay"]
        WriteLog("⏸️ 下注延迟修改已取消", 2)
    }
}

OnClickDelayLoseFocus(*) {
    global clickDelayEdit, UserConfig, CurrentUserKey
    value := clickDelayEdit.Text
    if !IsNumber(value) || value <= 0 {
        MsgBox "⚠️ 请输入有效的数字（大于0）！"
        clickDelayEdit.Text := UserConfig["ClickDelay"]
        return
    }
    
    ; ★★★ 弹出确认框 ★★★
    result := MsgBox("确定要将点击延迟修改为 " . value . " ms 吗？`n`n点击「是」保存到云端，点击「否」取消修改。", "确认修改", "YesNo")
    if result = "Yes" {
        UserConfig["ClickDelay"] := Integer(value)
        clickDelayEdit.Text := UserConfig["ClickDelay"]
        SyncDelayToCloudAll(CurrentUserKey, UserConfig["BetDelay"], UserConfig["ClickDelay"])
        ToolTip "✅ 点击延迟已同步到云端: " . value . " ms"
        SetTimer(ToolTipClear, -2000)
        WriteLog("📝 点击延迟已保存到云端: " . value, 2)
    } else {
        clickDelayEdit.Text := UserConfig["ClickDelay"]
        WriteLog("⏸️ 点击延迟修改已取消", 2)
    }
}
