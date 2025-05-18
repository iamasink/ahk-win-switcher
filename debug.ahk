#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

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

F9:: {
    hwnd := WinExist("A")
    if !hwnd {
        MsgBox("no window")
        return
    }

    debugGui := Gui("+AlwaysOnTop +Resize", "Icon Debug - HWND: " Format("0x{:X}", hwnd))
    debugGui.SetFont("s10", "Segoe UI")
    yPos := 10, icons := []
    exePath := WinGetProcessPath("ahk_id " hwnd)
    isUWP := InStr(exePath, "ApplicationFrameHost.exe")

    iconcheck("01. WM_GETICON (ICON_SMALL)", GetIcon_WM(hwnd, 0))
    iconcheck("02. WM_GETICON (ICON_BIG)", GetIcon_WM(hwnd, 1))
    iconcheck("03. Class Small (GCL_HICONSM)", GetClassIcon(hwnd, -14))
    iconcheck("04. Class Large (GCL_HICON)", GetClassIcon(hwnd, -34))

    if exePath {
        iconcheck("05. EXE Icon (SHGetFileInfo)", GetEXEIcon_SH(exePath))
        iconcheck("06. EXE First Icon (ExtractIcon)", GetEXEIcon_Extract(exePath))
    }

    if isUWP {
        uwmHwnd := GetUWPChild(hwnd)
        iconcheck("07. UWP AUMID Icon", GetUWPIcon_AUMID(uwmHwnd))
        iconcheck("08. UWP PFN Icon", GetUWPIcon_PFN(uwmHwnd))
    }

    iconcheck("09. System Image List", GetSystemImageListIcon(exePath))
    iconcheck("10. Stock Application Icon", GetStockIcon(0x7F))  ; IDI_APPLICATION
    iconcheck("11. Stock Settings Icon", GetStockIcon(0x1001))    ; SIID_SETTINGS

    debugGui.Add("Button", "x10 y" yPos " w100", "Close").OnEvent("Click", (*) => debugGui.Destroy())
    debugGui.OnEvent("Close", CleanupIcons)
    debugGui.Show("AutoSize")

    iconcheck(name, hIcon) {
        debugGui.Add("Text", "x10 y" yPos " w200", name)
        status := debugGui.Add("Text", "x220 y" yPos " w200", hIcon ? "0x" Format("{:X}", hIcon) : "Failed")

        if hIcon {
            try {
                debugGui.Add("Picture", "x400 y" yPos - 5 " w32 h32", "HICON:" hIcon)
                icons.Push(hIcon)
            } catch {
                status.Text := "Invalid"
            }
        }
        yPos += 40
    }

    CleanupIcons(*) {
        for hIcon in icons
            if hIcon && DllCall("IsIconic", "Ptr", hIcon)
                DllCall("DestroyIcon", "Ptr", hIcon)
        debugGui.Destroy()
    }

    GetIcon_WM(hwnd, type) {
        try return SendMessage(0x7F, type, 0, , "ahk_id " hwnd)  ; WM_GETICON
    }

    GetClassIcon(hwnd, index) {
        return DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", index, "Ptr")
    }

    GetEXEIcon_SH(exePath) {
        sfi := Buffer(8 + (A_PtrSize * 6), 0)
        if DllCall("Shell32\SHGetFileInfo", "Str", exePath, "UInt", 0,
            "Ptr", sfi.Ptr, "UInt", sfi.Size, "UInt", 0x101)  ; SHGFI_ICON|SHGFI_LARGEICON
            return NumGet(sfi, 0, "Ptr")
    }

    GetEXEIcon_Extract(exePath) {
        return DllCall("Shell32\ExtractIcon", "Ptr", 0, "Str", exePath, "UInt", 0, "Ptr")
    }

    GetUWPChild(parentHwnd) {
        children := WinGetControlsHwnd("ahk_id " parentHwnd)
        return children.Length ? children[1] : 0
    }

    GetUWPIcon_AUMID(uwmHwnd) {
        aumid := WinGetTitle("ahk_id " uwmHwnd)
        if !aumid
            return 0
        return DllCall("Shell32\ExtractAssociatedIcon", "Ptr", 0,
            "Str", "shell:AppsFolder\" aumid, "UShort*", 0)
    }

    GetUWPIcon_PFN(uwmHwnd) {
        try {
            exePath := WinGetProcessPath("ahk_id " uwmHwnd)
            return DllCall("Shell32\ExtractAssociatedIcon", "Ptr", 0, "Str", exePath, "UShort*", 0)
        }
    }

    GetSystemImageListIcon(exePath) {
        sfi := Buffer(8 + (A_PtrSize * 6), 0)
        if DllCall("Shell32\SHGetFileInfo", "Str", exePath, "UInt", 0,
            "Ptr", sfi.Ptr, "UInt", sfi.Size, "UInt", 0x4000)  ; SHGFI_SYSICONINDEX
            return NumGet(sfi, 0, "Ptr")
    }

    GetStockIcon(id) {
        iconInfo := Buffer(8 + (A_PtrSize * 2))
        if DllCall("Shell32\SHGetStockIconInfo", "UInt", id, "UInt", 0x101, "Ptr", iconInfo) = 0  ; SHGSI_ICON|SHGSI_LARGEICON
            return NumGet(iconInfo, A_PtrSize, "Ptr")
    }
}

F8:: {
    hwnd := WinExist("A")
    if !hwnd {
        MsgBox("No active window")
        return
    }

    logoPath := GetLargestUWPLogoPath(hwnd)
    if !logoPath {
        MsgBox("Not a UWP app or no logo found")
        return
    }

    if !FileExist(logoPath) {
        MsgBox("Logo file not found:`n" logoPath)
        return
    }

    ; Create preview GUI
    previewGui := Gui("+AlwaysOnTop +ToolWindow", "UWP Logo Preview")
    previewGui.SetFont("s10", "Segoe UI")
    previewGui.Add("Text", "w500", "Path: " logoPath)
    previewGui.Add("Picture", "w256 h256", logoPath)
    previewGui.Add("Button", "Default w100", "Close").OnEvent("Click", (*) => previewGui.Destroy())
    previewGui.Show("AutoSize Center")

}

f7:: {

    hwnd := WinExist("A")

    w := 500
    h := 500
    G := Gui('+AlwaysOnTop')
    G.Show('w' w ' h' h)

    CreateThumbnail(hwnd, G.Hwnd, 0, 100)
}

CreateThumbnail(windowHwnd, thumbnailHwnd, x, y) {
    scale := 5

    WinGetPos(, , &sourceW, &sourceH, "ahk_id " windowHwnd)

    DllCall('dwmapi\DwmRegisterThumbnail', 'Ptr', thumbnailHwnd, 'Ptr', windowHwnd, 'Ptr*', &hThumbnailId := 0,
        'HRESULT')

    DWM_TNP_RECTDESTINATION := 0x00000001
    DWM_TNP_RECTSOURCE := 0x00000002
    DWM_TNP_OPACITY := 0x00000004
    DWM_TNP_VISIBLE := 0x00000008
    DWM_TNP_SOURCECLIENTAREAONLY := 0x00000010
    NumPut(
        'UInt', DWM_TNP_RECTDESTINATION | DWM_TNP_RECTSOURCE | DWM_TNP_VISIBLE,
        'Int', x, ; x of preview on gui
        'Int', y, ; y ''
        'Int', x + sourceW / scale, ; x2
        'Int', y + sourceH / scale, ; y2
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

GetLargestUWPLogoPath(hwnd) {
    Address := CallbackCreate(EnumChildProc.Bind(WinGetPID(hwnd)), 'Fast', 2)
    DllCall('User32.dll\EnumChildWindows', 'Ptr', hwnd, 'Ptr', Address, 'UInt*', &ChildPID := 0, 'Int'), CallbackFree(
        Address)
    return ChildPID && AppHasPackage(ChildPID) ? GetLargestLogoPath(GetDefaultLogoPath(ProcessGetPath(ChildPID))) : ''

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
        ProcessHandle := DllCall('Kernel32.dll\OpenProcess', 'UInt', PROCESS_QUERY_LIMITED_INFORMATION, 'Int', false,
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

    GetLargestLogoPath(Path) {
        ;     LoopFileSize := 99999999
        ;     SplitPath Path, , &Dir, &Extension, &NameNoExt
        ;     pathcandidates := []
        ;     loop files Dir '\' NameNoExt '.scale-*.' Extension {
        ;         if A_LoopFileSize <= LoopFileSize && RegExMatch(A_LoopFileName, '\d+\.' Extension '$') { ; Avoid contrast files.
        ;             LoopFilePath := A_LoopFilePath, LoopFileSize := A_LoopFileSize
        ;             pathcandidates.Push(LoopFilePath)
        ;             }

        ;             str := ""
        ;             for i in pathcandidates {
        ;                 str := str " " i
        ;             }
        ;             }
        ;             MsgBox(str)
        ; }


        SplitPath Path, , &Dir, &Extension, &NameNoExt

        ; allfiles := []
        best := ""
        besttype := 0

        target := 32

        loop files Dir "\" "*.png" {
            if RegExMatch(A_LoopFileName, ".*\.targetsize-256\." . Extension . "$") {
                type := 100
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.targetsize-96\." . Extension . "$") {
                type := 96
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.targetsize-72\." . Extension . "$") {
                type := 72
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.targetsize-48\." . Extension . "$") {
                type := 48
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.targetsize-36\." . Extension . "$") {
                type := 36
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.targetsize-32\." . Extension . "$") {
                type := 32
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
                if (type == target) {
                    best := A_LoopFilePath
                    besttype := 1000
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.scale-400\." . Extension . "$") {
                type := 4
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.scale-200\." . Extension . "$") {
                type := 3
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
            if RegExMatch(A_LoopFileName, ".*\.scale-100\." . Extension . "$") {
                type := 2
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }
        }


        return best
    }
}

f6:: {
    hwnd := WinExist("ahk_exe Code.exe")

    ; windowinfo := GetWindowInfo(hwnd)
    ; MsgBox(windowinfo.left "`n" windowinfo.right "`n" windowinfo.top "`n" windowinfo.bottom "`n" windowinfo.state)

    windowinfo := GetWindowNormalSize(hwnd)
    MsgBox(windowinfo.width "`n" windowinfo.height "`n" windowinfo.state)

    GetWindowNormalSize(hwnd) {
        static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

        ; Initialize WINDOWPLACEMENT structure
        wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
        NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)

        if DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp) {
            ; Extract values from structure
            showCmd := NumGet(wp, 8, "UInt")  ; showCmd at offset 8
            left := NumGet(wp, 28, "Int")   ; rcNormalPosition.left
            top := NumGet(wp, 32, "Int")   ; rcNormalPosition.top
            right := NumGet(wp, 36, "Int")   ; rcNormalPosition.right
            bottom := NumGet(wp, 40, "Int")   ; rcNormalPosition.bottom

            return {
                width: right - left,
                height: bottom - top,
                state: showCmd = SW_SHOWMINIMIZED ? "minimized"
                    : showCmd = SW_SHOWMAXIMIZED ? "maximized"
                        : "normal"
            }
        }

        ; Fallback if API call fails
        WinGetPos(, , &w, &h, "ahk_id " hwnd)
        return { width: w, height: h, state: "unknown" }
    }

    GetWindowInfo(hwnd) {
        static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

        ; Initialize WINDOWPLACEMENT structure
        wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
        NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)

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
                top: top,
                bottom: bottom,
                state: showCmd = SW_SHOWMINIMIZED ? "minimized"
                    : showCmd = SW_SHOWMAXIMIZED ? "maximized"
                        : "normal"
            }
        }
    }
}

f4:: {
    ; display monitor info
    moncount := MonitorGetCount()
    i := 0
    String := "Monitor num: l,t,r,b`n"
    loop MonitorGetCount() {
        monitor := MonitorGet(i, &left, &top, &right, &bottom)
        String := String "Monitor " i ": " left "," top "," right "," bottom "`n"
        i += 1
    }
    MsgBox(String)
}

F3:: ShowWindowInfo()

ShowWindowInfo() {
    static lastPos := Map()

    try {
        hwnd := WinExist("A")  ; active window
        title := WinGetTitle("ahk_id " hwnd)
        pid := WinGetPID("ahk_id " hwnd)
        processName := ProcessGetName(pid)

        ; get window position and center point
        WinGetPos(&winX, &winY, &winW, &winH, hwnd)
        winCenterX := winX + (winW / 2)
        winCenterY := winY + (winH / 2)

        ; get monitor containing window center point
        monNum := GetMonitorAt(winCenterX, winCenterY)
        MonitorGet(monNum, &monLeft, &monTop, &monRight, &monBottom)
        MonitorGetWorkArea(monNum, &workLeft, &workTop, &workRight, &workBottom)

        ; window styles
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")  ; GWL_STYLE
        exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")  ; GWL_EXSTYLE

        info := "Window Title: `t" . title . "`n"
            . "Process: `t`t" . processName . " (" . pid . ")`n"
            . "Position: `t`t" . winX . ", " . winY . "`n"
            . "Size: `t`t" . winW . " x " . winH . "`n"
            . "Center Point: `t" . winCenterX . ", " . winCenterY . "`n"
            . "Monitor: `t`t#" . monNum . " (Area: " . monLeft . "," . monTop . " - " . monRight . "," . monBottom . ")`n"
            . "Work Area: `t" . workLeft . "," . workTop . " - " . workRight . "," . workBottom . "`n"
            . "Style: `t`t0x" . Format("{:X}", style) . "`n"
            . "ExStyle: `t0x" . Format("{:X}", exStyle)

        ToolTip(info, A_ScreenWidth / 2, A_ScreenHeight / 2)
        SetTimer(() => ToolTip(), -5000)  ; 5s
    } catch as e {
        MsgBox "Error getting window info: " e.Message
    }
}


f2:: {
    hwnd := WinExist("A")
    if !hwnd {
        MsgBox("No active window")
        return
    }

    dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    scalingFactor := dpi / 96

    ; Retrieve the normal position using GetWindowNormalPos
    normalPos := GetWindowNormalPos(hwnd)

    state := 0
    if (WinGetMinMax("ahk_id " hwnd) == 1) {
        state := "maximized"
    } else if (WinGetMinMax("ahk_id " hwnd) == -1) {
        state := "minimized"
    } else {
        state := "normal"
    }

    ; Debug: Retrieve the normal position using WINDOWPLACEMENT structure
    wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
    NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)

    if DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp) {
        ; Extract values from structure
        left := NumGet(wp, 28, "Int")   ; rcNormalPosition.left
        top := NumGet(wp, 32, "Int")   ; rcNormalPosition.top
        right := NumGet(wp, 36, "Int")   ; rcNormalPosition.right
        bottom := NumGet(wp, 40, "Int")   ; rcNormalPosition.bottom

        debugNormalPos := {
            left: Floor(left),
            top: Floor(top),
            width: Floor((right - left) * scalingFactor),
            height: Floor((bottom - top) * scalingFactor)
        }

        ; Display debug information
        MsgBox(" Position via getwindowplacement dllcall:`n"
            . "Left: " debugNormalPos.left "`n"
            . "Top: " debugNormalPos.top "`n"
            . "Width: " debugNormalPos.width "`n"
            . "Height: " debugNormalPos.height "`n"
            . "Scaling Factor: " scalingFactor "`n"
            . "DPI: " dpi "`n"
            . "State: " state "`n"
            . "Window Title: " WinGetTitle("ahk_id " hwnd) "`n"
            . "Window ID: " hwnd "`n"
            . "Process ID: " WinGetPID("ahk_id " hwnd) "`n"
            . "Process Name: " ProcessGetName(WinGetPID("ahk_id " hwnd)) "`n"
        )
    }
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    ; Display the normal position in a message box
    MsgBox("pos via wingetpos:`n" "Left: " x "`n"
        . "Top: " y "`n"
        . "Width: " w "`n"
        . "Height: " h "`n"
        . "Scaling Factor: " scalingFactor "`n"
        . "DPI: " dpi "`n"
        . "State: " state "`n"
        . "Window Title: " WinGetTitle("ahk_id " hwnd) "`n"
        . "Window ID: " hwnd "`n"
        . "Process ID: " WinGetPID("ahk_id " hwnd) "`n"
        . "Process Name: " ProcessGetName(WinGetPID("ahk_id " hwnd)) "`n"
    )

    ; display positions visually with positioned tooltip
    ToolTip(".", x, y, 2)
    ToolTip(">", x + w, y, 3)
    ToolTip(".", x + w, y + h, 4)
    ToolTip("v", x, y + h, 5)

    ; display other position with tooltips too
    ToolTip("x", debugNormalPos.left, debugNormalPos.top, 6)
    ToolTip(">", debugNormalPos.left + debugNormalPos.width, debugNormalPos.top, 7)
    ToolTip("v", debugNormalPos.left, debugNormalPos.top + debugNormalPos.height, 8)
    ToolTip("x", debugNormalPos.left + debugNormalPos.width, debugNormalPos.top + debugNormalPos.height, 9)

}


f1:: {
    GetWindowNormalPos(hwnd, scalingFactorOverride := 0) {
        static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

        dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
        ; 96 is 100% i think
        scalingFactor := scalingFactorOverride ? scalingFactorOverride : dpi / 96
        ; scalingFactor := 1
        ; MsgBox("window: " WinGetTitle("ahk_id " hwnd) "`n" hwnd "`n dpi: " dpi "`n scalingFactor: " scalingFactor)

        ; MsgBox("dpi: " dpi)

        state := WinGetMinMax("ahk_id" hwnd)


        ; if fullscreen
        if (state == 1) {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)


            ; winMon := GetMonitorAt(centerX, centerY)


            ; MonitorGetWorkArea(winMon, &left, &top, &right, &bottom)


            ;         return {
            ;     left: left,
            ;     top: top,
            ;     bottom: bottom,
            ;     right: right,
            ;     width: right - left,
            ;     height: bottom - top
            ; }

            return {
                left: x,
                top: y,
                bottom: y + h,
                right: x + w,
                width: w,
                height: h
            }
        }

        ; if normal
        if (state == 0) {

            ; ; old wingetpos method
            ; title := WinGetTitle("ahk_id " hwnd)
            ; ; the window is maximised or normal
            ; WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

            ; return {
            ;     left: Floor((x) * scalingFactor),
            ;     right: Floor((x + w) * scalingFactor),
            ;     bottom: Floor((y + h) * scalingFactor),
            ;     top: Floor((y) * scalingFactor),
            ;     width: Floor((w) * scalingFactor),
            ;     height: Floor((h) * scalingFactor)
            ; }


            ; new DwmGetWindowAttribute DWMWA_EXTENDED_FRAME_BOUNDS method

            static DWMWA_EXTENDED_FRAME_BOUNDS := 9
            rect := Buffer(16, 0)  ; RECT structure: 4 integers (4 bytes each)
            hResult := DllCall("dwmapi\DwmGetWindowAttribute",
                "Ptr", hwnd,
                "UInt", DWMWA_EXTENDED_FRAME_BOUNDS,
                "Ptr", rect,
                "UInt", rect.Size)
            if (hResult != 0)
                throw OSError("DwmGetWindowAttribute failed", hResult)
            extendedframeboundsleft := NumGet(rect, 0, "Int")
            extendedframeboundstop := NumGet(rect, 4, "Int")
            extendedframeboundsright := NumGet(rect, 8, "Int")
            extendedframeboundsbottom := NumGet(rect, 12, "Int")

            ; return {
            ;     left: extendedframeboundsleft,
            ;     top: extendedframeboundstop,
            ;     bottom: extendedframeboundsbottom,
            ;     right: extendedframeboundsright,
            ;     width: extendedframeboundsright - extendedframeboundsleft,
            ;     height: extendedframeboundsbottom - extendedframeboundstop
            ; }


        }

        ; MsgBox("window: " WinGetTitle("ahk_id " hwnd) "`n" hwnd "`n dpi: " dpi "`n scalingFactor: " scalingFactor)

        ; Initialize WINDOWPLACEMENT structure
        wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
        NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)
        if DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp) {
            ; Extract values from structure
            showCmd := NumGet(wp, 8, "UInt")  ; showCmd at offset 8
            left := NumGet(wp, 28, "Int")   ; rcNormalPosition.left
            top := NumGet(wp, 32, "Int")   ; rcNormalPosition.top
            right := NumGet(wp, 36, "Int")   ; rcNormalPosition.right
            bottom := NumGet(wp, 40, "Int")   ; rcNormalPosition.bottom

            return {
                left: Floor((left) * scalingFactor),
                right: Floor((right) * scalingFactor),
                bottom: Floor((bottom) * scalingFactor),
                top: Floor((top) * scalingFactor),
                width: Floor((right - left) * scalingFactor),
                height: Floor((bottom - top) * scalingFactor),
                ; state: showCmd = SW_SHOWMINIMIZED ? "minimized"
                ;     : showCmd = SW_SHOWMAXIMIZED ? "maximized"
                ;         : "normal"
            }
        }
    }

}

GetWindowNormalPos(hwnd) {
    static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

    dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    ; 96 is 100% i think
    scalingFactor := dpi / 96
    ; scalingFactor := 1
    ; MsgBox("window: " WinGetTitle("ahk_id " hwnd) "`n" hwnd "`n dpi: " dpi "`n scalingFactor: " scalingFactor)

    ; MsgBox("dpi: " dpi)

    ; Initialize WINDOWPLACEMENT structure
    wp := Buffer(44, 0)                   ; Size of WINDOWPLACEMENT struct
    NumPut("UInt", 44, wp, 0)             ; Set cbSize (structure size)

    if (WinGetMinMax("ahk_id " hwnd) == 1) {
        title := WinGetTitle("ahk_id " hwnd)
        ; the window is maximised
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return {
            left: Floor((x) * scalingFactor),
            right: Floor((x + w) * scalingFactor),
            bottom: Floor((y + h) * scalingFactor),
            top: Floor((y) * scalingFactor),
            width: Floor((w) * scalingFactor),
            height: Floor((h) * scalingFactor)
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
            left: Floor((left) * scalingFactor),
            right: Floor((right) * scalingFactor),
            bottom: Floor((bottom) * scalingFactor),
            top: Floor((top) * scalingFactor),
            width: Floor((right - left) * scalingFactor),
            height: Floor((bottom - top) * scalingFactor),
            ; state: showCmd = SW_SHOWMINIMIZED ? "minimized"
            ;     : showCmd = SW_SHOWMAXIMIZED ? "maximized"
            ;         : "normal"
        }
    }
}

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

#HotIf WinActive(A_ScriptName " ahk_exe Code.exe")
~^s:: {
    ToolTip("Reloading " A_ScriptName ".", A_ScreenWidth / 2, A_ScreenHeight / 2)
    Sleep(250)
    Reload()
}
