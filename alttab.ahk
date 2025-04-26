#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")

#DllLoad 'dwmapi'


; if not admin, start as admin
; taken from https://www.autohotkey.com/boards/viewtopic.php?p=523250#p523250

; if (!A_IsAdmin) {
;     try {
;         ; MsgBox("Running as admin...")
;         Run("*RunAs `"" A_ScriptFullPath "`"")
;         ; wait, so that the script doesnt continue running and instead restarts as admin (hopefully) before this runs out, otherwise it will just close.
;         Sleep(10000)
;         MsgBox("Couldn't run " A_ScriptName " as admin! Exiting..")
;         Sleep(5000)
;         ExitApp()
;     }
;     catch {
;         MsgBox("Couldn't run " A_ScriptName " as admin! Exiting..")
;         Sleep(5000)
;         ExitApp()
;     }
; }

global altDown := false
global tabPressed := false
global altPressTime := 0
global switcherGui := Gui()
global switcherShown := false
global windows := []
global existingHWNDs := Map()
global switcherGuiTexts := []
global switcherGuiBackgrounds := []
global switcherGuiLogos := []
global selectedIndex := 1
global lastIndex := 2
global iconCache := Map()
global showMonitor := 0

;

global backgroundColour := "202020"
global textColour := "ffffff"
global selectedColour := "ff8aec"

f12:: {
    ExitApp
}

f11:: {
    BuildWindowList()
    ShowSwitcher()
}

; if alt tab tapped, just change switcher
; if alt is still held after some time, show menu
; if alt is released, hide menu

*~LAlt:: {
    global altDown, altPressTime, showGUI, tabPressed
    altDown := true
    showGUI := false
    tabPressed := false

    altPressTime := A_TickCount

    ; ToolTip("alt down`n " tabPressed, , , 2)
    SetTimer(AltDownLoop, -1)
    KeyWait("LAlt")
    altDown := false

}

AltDownLoop() {
    global altDown, altPressTime, showGUI, tabPressed, switcherShown, selectedIndex, lastIndex, windows, showMonitor
    if (altDown) {
        if (tabPressed) {
            if (windows.Length = 0) {
                BuildWindowList(showMonitor ? showMonitor : GetMouseMonitor())
            }
            if (altPressTime + 150 < A_TickCount) {
                if (!switcherShown) {
                    if (windows.Length > 0) {
                        ShowSwitcher(GetMouseMonitor())
                        ChangeGuiSelectedText(selectedIndex, lastIndex)
                    } else {
                        ToolTip("no windows...")
                    }
                }
            } else {
            }
        }
        SetTimer(AltDownLoop, -1)
    } else {
        ; when alt released
        if (tabPressed) {
            if (switcherShown) {
                if (selectedIndex >= 1 && selectedIndex <= windows.Length) {
                    ; ChangeSwitcherSelection(selectedIndex, lastIndex)
                }
                HideSwitcher()
                switcherShown := false
            }
            ; tempwindowstring := ""
            ; for index, w in windows {
            ;     tempwindowstring := tempwindowstring w.title "`n"
            ; }
            ; ToolTip("focus index " selectedIndex "`n windows: " tempwindowstring)
            if (windows.Length > 0) {
                FocusWindow(windows[selectedIndex].hwnd)
            }
            windows := []
            selectedIndex := 1
            lastIndex := 1
        } else {
            ; ToolTip("no tab", , , 10)
        }
    }
}

#HotIf altDown
*Tab:: {
    global tabPressed
    tabPressed := true
    HandleTab(1)
}

*+Tab:: {
    global tabPressed
    tabPressed := true
    HandleTab(-1)
}

*`:: {
    global showMonitor, selectedIndex, tabPressed
    tabPressed := true

    ; showMonitor += 1
    ; monitorCount := MonitorGetCount()
    ; if showMonitor > MonitorGetCount() {
    ;     showMonitor := 1
    ; }
    ; if showMonitor < 1 {
    ;     showMonitor := MonitorGetCount()
    ; }
    ; ToolTip(showMonitor)
    ; HideSwitcher()
    ; selectedIndex := 1
    ; BuildWindowList(showMonitor ? showMonitor : GetMouseMonitor())
    ; ShowSwitcher()
    ; ChangeGuiSelectedText(1, 1)

    HandleTilde(1)
}

+`::{
    global showMonitor, selectedIndex, tabPressed
    tabPressed := true
    HandleTilde(-1)
}

*1::HandleNumber(1)
*2::HandleNumber(2)
*3::HandleNumber(3)
*4::HandleNumber(4)
*5::HandleNumber(5)
*6::HandleNumber(6)
*7::HandleNumber(7)
*8::HandleNumber(8)
*9::HandleNumber(9)
*0::HandleNumber(0)

*WheelDown::HandleTab(1)
*WheelUp::HandleTab(-1)

; rebind scroll click to right click
*MButton::RButton
#HotIf

HandleTab(change) {
    global selectedIndex, switcherShown, lastIndex, windows
    lastIndex := selectedIndex
    selectedIndex += change
    if (windows.Length > 0) {
        if (selectedIndex > windows.Length) {
            selectedIndex := 1
        }
        if (selectedIndex < 1) {
            selectedIndex := windows.Length
        }
    }
    ; ToolTip("change: " change "`n" selectedIndex)
    if switcherShown {
        ChangeGuiSelectedText(selectedIndex, lastIndex)
    }
}

HandleTilde(change) {
    global showMonitor, selectedIndex, tabPressed
    showMonitor += change
    monitorCount := MonitorGetCount()
    if showMonitor > monitorCount {
        showMonitor := 1
    }
    if showMonitor < 1 {
        showMonitor := monitorCount
    }
    ; ToolTip("change: " change "`n" showMonitor)
    BuildWindowList(showMonitor)
    ShowSwitcher()
    selectedIndex := 1
    if switcherShown {
        ChangeGuiSelectedText(selectedIndex, lastIndex)
    }
}

HandleNumber(num) {
    global showMonitor, selectedIndex,lastIndex, tabPressed, windows
    if (num > 0 && num < windows.Length) {
        ChangeSelectedIndex(num)
        ; selectedIndex := num
    } else {
        ChangeSelectedIndex(windows.Length)
        ; selectedIndex := windows.Length
    }
    if switcherShown {
        ChangeGuiSelectedText(selectedIndex, lastIndex)
    }
}

BuildWindowList(monitorNum := MonitorGetPrimary()) {
    global windows, existingHWNDs
    windows := []
    DetectHiddenWindows(false)
    static WS_POPUP := 0x80000000, WS_CHILD := 0x40000000
    static WS_EX_TOOLWINDOW := 0x80, WS_EX_APPWINDOW := 0x40000
    static GW_OWNER := 4, DWMWA_CLOAKED := 14
    scriptPID := ProcessExist()
    for hwnd in WinGetList() {
        winpos := GetWindowNormalPos(hwnd)
        centerX := winpos.left + (winpos.width // 2)
        centerY := winpos.top + (winpos.height // 2)

        winMon := GetMonitorAt(centerX, centerY)
        if (winMon != monitorNum)
            continue

        if !DllCall("IsWindowVisible", "Ptr", hwnd) {
            continue
        }

        ; skip windows of this script
        try if WinGetPID("ahk_id " hwnd) == scriptPID {
            continue
        }

        ; check window styles
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr") ; GWL_STYLE
        exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr") ; GWL_EXSTYLE

        ; Skip tool windows and child windows
        if (exStyle & WS_EX_TOOLWINDOW) || (style & WS_CHILD) {
            continue
        }

        ; skip windows with owner
        if DllCall("GetWindow", "Ptr", hwnd, "UInt", GW_OWNER, "Ptr") {
            continue
        }

        ; check DWMWA_CLOAKED
        ; cloaked := 0
        ; if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_CLOAKED, "Int*", &cloaked, "Int", 4) == 0
        ;     if cloaked {
        ;         continue
        ;     }

        ; check window transparency
        ; maybe this is weird with some fancy windows..
        transColor := 0, transAlpha := 0, flags := 0
        if DllCall("GetLayeredWindowAttributes", "Ptr", hwnd, "UInt*", &transColor, "UChar*", &transAlpha, "UInt*", &flags)
            if (transAlpha = 0) || (flags & 0x1) ; LWA_ALPHA=0x2, LWA_COLORKEY=0x1
                continue

        title := WinGetTitle("ahk_id " hwnd)
        ; check title with weird regex
        if (title = "" || title ~= "i)(Program Manager|Windows Input Experience|SearchApp|ShellExperienceHost)")
            continue

        ; if !existingHWNDs.Has(hwnd) {
        windows.Push({ hwnd: hwnd, title: title })
        ; existingHWNDs.Set(hwnd, true)
        ; }
    }
}

ShowSwitcher(onMonitor := MonitorGetPrimary()) {
    global switcherGui, windows, selectedIndex, switcherGuiTexts, switcherShown, showMonitor, backgroundColour, textColour
    useThumbnails := true
    if (useThumbnails) {



        try {
            HideSwitcher()
        }
        switcherGui := Gui("")
        switcherGui.BackColor := backgroundColour
        ; WinSetTransColor("000000", "ahk_id " switcherGui.hwnd)
        ; WinSetRegion("W100 H100")
        switcherGui.Opt("-Caption +ToolWindow +Resize -DPIScale")
    
        switcherGuiTexts := []
        switcherGui.AddText("y0 x10 c" textColour, "Monitor: " (showMonitor ? showMonitor : GetMouseMonitor()))
    
        y := 30
        ydiff := 400
        thumbHeight := 200
        rowHeight := thumbHeight + 50
        row := 0
        numonrow := 0



        winWidth := 0
        winHeight := 0
        xPos := 100
        yPos := 10
        
        
        for index, w in windows {


            windowinfo := GetWindowNormalPos(w.hwnd)
            windowW := windowinfo.width
            windowH :=  windowinfo.height
            ; calculate thumbwidth keeping aspect ratio
            thumbWidth := Floor(thumbHeight * (windowW / windowH))


            backgroundctl := switcherGui.AddText("y" yPos " x" xPos - 10 " w" thumbWidth + 20 " h" thumbHeight + 50 " c" textColour, "")
            logoctl := switcherGui.addPicture("y" yPos  " x" xPos " w32 h32", GetWindowIcon(w.hwnd))
            textctl := switcherGui.AddText("y" yPos + 8 " x" xPos + 40 " c" textColour, "w" index ": " w.title)
            ; run this function with parameters
            textctl.OnEvent("Click", TextClick.Bind(textctl, index))
            backgroundctl.OnEvent("ContextMenu", TextMiddleClick.Bind(textctl, index))
            switcherGuiTexts.InsertAt(index, backgroundctl)
            ; switcherGuiBackgrounds.InsertAt(index, backgroundctl)
            ; switcherGuiLogos.InsertAt(index, logoctl)


            ; MsgBox(w.title "`n w: " windowW " h: " windowH)

            
            ; MsgBox("thumbwidth: " thumbWidth)


            CreateThumbnail(w.hwnd,switcherGui.hwnd,xPos,yPos + 35,windowW,windowH,thumbWidth,thumbHeight)
            
            xPos += thumbWidth + 50
            numonrow += 1

            if (xPos > winWidth) {
                winWidth := xPos + 50
            }
            if (yPos + rowHeight > winHeight) {
                winHeight := yPos + rowHeight
            }

            if (xPos > A_ScreenWidth * 0.8) {
                xPos := 100
                yPos += rowHeight
                numonrow := 0
            }

        }
        monitorinfo := GetMonitorCenter(onMonitor)
        switcherGui.Show("NoActivate x10000 y10000 w" 0 " h" 0)
        ; first make the window far away and very small, to hide the flash of white (maybe theres a better way to fix this)
        w := winWidth + 50
        h := winHeight + 50
        switcherGui.Opt("+AlwaysOnTop -Caption +ToolWindow +Resize -DPIScale")
        ; ensure all other guis are removed
        ; then make it big and centered
        switcherGui.Show("w" w " h" h "x" monitorinfo.x - (w / 2) " y" monitorinfo.y - (h / 2))
        switcherShown := true
    } else {
            try {
                HideSwitcher()
            }
            switcherGui := Gui("")
            switcherGui.BackColor := backgroundColour
            ; WinSetTransColor("000000", "ahk_id " switcherGui.hwnd)
            ; WinSetRegion("W100 H100")
            switcherGui.Opt("-Caption +ToolWindow +Resize -DPIScale")
            switcherGuiTexts := []
            switcherGui.AddText("y0 x10 c" textColour, "Monitor: " (showMonitor ? showMonitor : GetMouseMonitor()))
            
            y := 30
            ydiff := 40
            
            for index, w in windows {
                switcherGui.addPicture("y" y - 10 " x5 w32 h32", GetWindowIcon(w.hwnd))
                textctl := switcherGui.AddText("y" y " x40 c" textColour, "w" index ": " w.title)
                ; run this function with parameters
                textctl.OnEvent("Click", TextClick.Bind(textctl, index))
                switcherGuiTexts.InsertAt(index, textctl)
                y += ydiff
            }
            monitorinfo := GetMonitorCenter(onMonitor)
            switcherGui.Show("NoActivate x10000 y10000 w" 0 " h" 0)
            ; first make the window far away and very small, to hide the flash of white (maybe theres a better way to fix this)
            w := 500
            h := 500
            switcherGui.Opt("+AlwaysOnTop -Caption +ToolWindow +Resize -DPIScale")
            ; ensure all other guis are removed
            ; then make it big and centered
            switcherGui.Show("w" w " h" h " x" monitorinfo.x - (500 / 2) " y" monitorinfo.y - (500 / 2))
            switcherShown := true
    }
}

TextClick(ctl, index, text, idk) {
    global selectedIndex, altDown
    ; MsgBox("hi " index)
    ; HideSwitcher()
    ; set the index then act as if alt was released
    ; selectedIndex := index
    ChangeSelectedIndex(index)
    ; tabPressed := false
    altDown := false
    HideSwitcher()
    ; FocusWindow(windows[index].hwnd)
}

TextMiddleClick(ctl, index, text, *) {
    global selectedIndex, altDown

    ; close the window
    WinClose("ahk_id " windows[index].hwnd)
    BuildWindowList()
    if (selectedIndex > windows.Length) {
        selectedIndex := windows.Length
    } else if (selectedIndex < 1) {
        selectedIndex := 1
    }
    ShowSwitcher()
    ChangeGuiSelectedText(selectedIndex, lastIndex)
}

ChangeSelectedIndex(index) {
    global selectedIndex, lastIndex
    lastIndex := selectedIndex
    selectedIndex := index
}



CreateThumbnail(windowHwnd, thumbnailHwnd, guiPosX, guiPosY, sourceW, sourceH, thumbW, thumbH) {

    DllCall('dwmapi\DwmRegisterThumbnail', 'Ptr', thumbnailHwnd, 'Ptr', windowHwnd, 'Ptr*', &hThumbnailId := 0,
        'HRESULT')

    DWM_TNP_RECTDESTINATION := 0x00000001
    DWM_TNP_RECTSOURCE := 0x00000002
    DWM_TNP_OPACITY := 0x00000004
    DWM_TNP_VISIBLE := 0x00000008
    DWM_TNP_SOURCECLIENTAREAONLY := 0x00000010
    NumPut(
        'UInt', DWM_TNP_RECTDESTINATION | DWM_TNP_RECTSOURCE | DWM_TNP_VISIBLE,
        'Int', guiPosX, ; x of preview on gui
        'Int', guiPosY, ; y ''
        'Int', guiPosX + thumbW, ; x2
        'Int', guiPosY + thumbH, ; y2
        'Int', 0, ; start x of source
        'Int', 0, ; start y of source
        'Int', sourceW, ; x2 of source?
        'Int', sourceH, ;  y2 of source?
        Properties := Buffer(45, 0)
    )
    NumPut('UInt', true, Properties, 37)

    DllCall('dwmapi\DwmUpdateThumbnailProperties', 'Ptr', hThumbnailId, 'Ptr', Properties, 'HRESULT')
    return hThumbnailId
}

ChangeGuiSelectedText(index, lastIndex) {
    global switcherGuiTexts, switcherShown
    try {
            if (lastIndex >= 1 && lastIndex <= switcherGuiTexts.Length) {
                switcherGuiTexts[lastIndex].Opt("Background" backgroundColour)
                switcherGuiTexts[lastIndex].Redraw()
            }
            if (index >= 1 && index <= switcherGuiTexts.Length) {
                switcherGuiTexts[index].Opt("Background" selectedColour)
                switcherGuiTexts[index].Redraw()
            }
    }
}

; ChangeGuiSelectedBackground(index, lastIndex) {
;     global switcherGuiBackgrounds, switcherShown
;     try {
;             if (lastIndex >= 1 && lastIndex <= switcherGuiBackgrounds.Length) {
;                 switcherGuiBackgrounds[lastIndex].Opt("Background" backgroundColour)
;                 switcherGuiBackgrounds[lastIndex].Redraw()
;             }
;             if (index >= 1 && index <= switcherGuiBackgrounds.Length) {
;                 switcherGuiBackgrounds[index].Opt("Background" selectedColour)
;                 switcherGuiBackgrounds[index].Redraw()
;             }
;     }
; }

HideSwitcher() {
    global switcherGui
    switcherGui.Destroy()
}

FocusWindow(hwnd) {
    ; WinActivate("ahk_id " hwnd)
    ; try DllCall("SetForegroundWindow", "Ptr", hwnd)

    if !WinExist("ahk_id " hwnd)
        return false

    WinActivate("ahk_id " hwnd)

    return true
}

; Find monitor at coordinates
GetMonitorAt(X, Y) {
    monitorCount := MonitorGetCount()
    loop monitorCount {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (X >= L && X <= R && Y >= T && Y <= B) {
            return A_Index
        }
    }
    return 1
}

GetMonitorCenter(monitorNum) {
    MonitorGet(monitorNum, &L, &T, &R, &B)
    x := (L + R) // 2
    y := (T + B) // 2
    return { x: x, y: y }
}

; get the window's actual size and pos, even if its minimized
GetWindowNormalPos(hwnd) {
    static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

    ; Initialize WINDOWPLACEMENT structure
    wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
    NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)

    if (WinGetMinMax("ahk_id " hwnd) == 1) {
        title := WinGetTitle("ahk_id " hwnd)
        ; the window is maximised
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return {
            left : x,
            right : x+w,
            bottom : y+h,
            top : y,
            width: w,
            height: h
        }
    }

    if DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp) {
        ; Extract values from structure
        showCmd := NumGet(wp, 8, "UInt")  ; showCmd at offset 8
        left := NumGet(wp, 28, "Int")   ; rcNormalPosition.left
        top := NumGet(wp, 32, "Int")   ; rcNormalPosition.top
        right := NumGet(wp, 36, "Int")   ; rcNormalPosition.right
        bottom := NumGet(wp, 40, "Int")   ; rcNormalPosition.bottom

        return {
            left: left,
            right: right,
            bottom: bottom,
            top: top,
            width: right - left,
            height: bottom - top,
            ; state: showCmd = SW_SHOWMINIMIZED ? "minimized"
            ;     : showCmd = SW_SHOWMAXIMIZED ? "maximized"
            ;         : "normal"
        }
    }
}

GetMouseMonitor() {
    MouseGetPos(&x, &y)
    return GetMonitorAt(x, y)
}

GetWindowIcon(hwnd) {
    static hShell32 := DllCall("LoadLibrary", "Str", "shell32.dll", "Ptr")

    ; Try WM_GETICON first
    ; try if hIcon := SendMessage(0x7F, 0, 0, , "ahk_id " hwnd)  ; WM_GETICON ICON_SMALL
    try if hIcon := SendMessage(0x7F, 1, 0, , "ahk_id " hwnd)  ; WM_GETICON ICON_BIG
        return "HICON:" hIcon

    ; Try class icons
    if hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr")  ; GCL_HICONSM
        return "HICON:" hIcon

    if hIcon := GetLargestUWPLogoPath(hwnd)
        return hIcon

    return ""

    ; tysm https://www.autohotkey.com/boards/viewtopic.php?t=127727
    GetLargestUWPLogoPath(hwnd) {
        global iconCache
        ; MsgBox("looking for uwp path")
        if (iconCache.Has(hwnd)) {
            ; we've already fetched this application's icon, so let's not do it again :)
            ; MsgBox("cache hit!")
            return iconCache[hwnd]
        }

        Address := CallbackCreate(EnumChildProc.Bind(WinGetPID(hwnd)), 'Fast', 2)
        DllCall('User32.dll\EnumChildWindows', 'Ptr', hwnd, 'Ptr', Address, 'UInt*', &ChildPID := 0, 'Int'),
        CallbackFree(Address)
        path := ChildPID && AppHasPackage(ChildPID) ? GetLogoPath(GetDefaultLogoPath(ProcessGetPath(ChildPID))) : ''
        iconCache[hwnd] := path
        return path

        EnumChildProc(PID, hwnd, lParam) {
            ChildPID := WinGetPID(hwnd)
            if ChildPID != PID {
                NumPut 'UInt', ChildPID, lParam
                return false
            }
            return true
        }

        AppHasPackage(ChildPID) {
            static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000, APPMODEL_ERROR_NO_PACKAGE := 15700
            ProcessHandle := DllCall('Kernel32.dll\OpenProcess', 'UInt', PROCESS_QUERY_LIMITED_INFORMATION, 'Int',
                false,
                'UInt', ChildPID, 'Ptr')
            IsUWP := DllCall('Kernel32.dll\GetPackageId', 'Ptr', ProcessHandle, 'UInt*', &BufferLength := 0, 'Ptr', 0,
                'Int') != APPMODEL_ERROR_NO_PACKAGE
            DllCall('Kernel32.dll\CloseHandle', 'Ptr', ProcessHandle, 'Int')
            return IsUWP
        }

        GetDefaultLogoPath(Path) {
            SplitPath Path, , &Dir
            if !RegExMatch(FileRead(Dir '\AppxManifest.xml', 'UTF-8'), '<Logo>(.*)</Logo>', &Match)
                throw Error('Unable to read logo information from file.', -1, Dir '\AppxManifest.xml')
            return Dir '\' Match[1]
        }

        GetLogoPath(Path) {
            LoopFileSize := 0
            SplitPath Path, , &Dir, &Extension, &NameNoExt
            loop files Dir '\' NameNoExt '.scale-*.' Extension
                if A_LoopFileSize > LoopFileSize && RegExMatch(A_LoopFileName, '\d+\.' Extension '$')  ; Avoid contrast files
                    LoopFilePath := A_LoopFilePath, LoopFileSize := A_LoopFileSize
            return LoopFilePath
        }
    }
}

; debug, restart script when saving in vscode
#HotIf WinActive(A_ScriptName " ahk_exe Code.exe")
~^s::
{
    ToolTip("Reloading " A_ScriptName ".", A_ScreenWidth / 2, A_ScreenHeight / 2)
    Sleep(250)
    Reload()
    return
}
