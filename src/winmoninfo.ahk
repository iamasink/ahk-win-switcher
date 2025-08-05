#Requires AutoHotkey v2.0

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

GetWindowMonitor(hwnd) {
    winpos := GetWindowNormalPos(hwnd)
    centerX := winpos.left + (winpos.width // 2)
    centerY := winpos.top + (winpos.height // 2)


    winMon := GetMonitorAt(centerX, centerY)
    return winMon
}

GetMonitorCenter(monitorNum) {
    MonitorGet(monitorNum, &L, &T, &R, &B)
    x := (L + R) // 2
    y := (T + B) // 2
    return { x: x, y: y }
}

; get the window's actual size and pos, even if its minimized
GetWindowNormalPos(hwnd, scalingFactorOverride := 0) {
    static SW_SHOWNORMAL := 1, SW_SHOWMINIMIZED := 2, SW_SHOWMAXIMIZED := 3

    dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    ; 96 is 100% i think
    scalingFactor := scalingFactorOverride ? scalingFactorOverride : dpi / 96
    ; scalingFactor := 1
    ; MsgBox("window: " WinGetTitle("ahk_id " hwnd) "`n" hwnd "`n dpi: " dpi "`n scalingFactor: " scalingFactor)

    ; MsgBox("dpi: " dpi)

    try {
        state := WinGetMinMax("ahk_id" hwnd)
    } catch {
        state := 2
    }


    ; if fullscreen
    if (state == 1 || state == 0) {
        try {


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
    }

    ; if normal
    ; if (state == 0) {

    ;     ; ; old wingetpos method
    ;     ; title := WinGetTitle("ahk_id " hwnd)
    ;     ; ; the window is maximised or normal
    ;     ; WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    ;     ; return {
    ;     ;     left: Floor((x) * scalingFactor),
    ;     ;     right: Floor((x + w) * scalingFactor),
    ;     ;     bottom: Floor((y + h) * scalingFactor),
    ;     ;     top: Floor((y) * scalingFactor),
    ;     ;     width: Floor((w) * scalingFactor),
    ;     ;     height: Floor((h) * scalingFactor)
    ;     ; }


    ;     ; new DwmGetWindowAttribute DWMWA_EXTENDED_FRAME_BOUNDS method

    ;     static DWMWA_EXTENDED_FRAME_BOUNDS := 9
    ;     rect := Buffer(16, 0)  ; RECT structure: 4 integers (4 bytes each)
    ;     hResult := DllCall("dwmapi\DwmGetWindowAttribute",
    ;         "Ptr", hwnd,
    ;         "UInt", DWMWA_EXTENDED_FRAME_BOUNDS,
    ;         "Ptr", rect,
    ;         "UInt", rect.Size)
    ;     if (hResult != 0)
    ;         throw OSError("DwmGetWindowAttribute failed", hResult)
    ;     extendedframeboundsleft := NumGet(rect, 0, "Int")
    ;     extendedframeboundstop := NumGet(rect, 4, "Int")
    ;     extendedframeboundsright := NumGet(rect, 8, "Int")
    ;     extendedframeboundsbottom := NumGet(rect, 12, "Int")

    ;     ; return {
    ;     ;     left: extendedframeboundsleft,
    ;     ;     top: extendedframeboundstop,
    ;     ;     bottom: extendedframeboundsbottom,
    ;     ;     right: extendedframeboundsright,
    ;     ;     width: extendedframeboundsright - extendedframeboundsleft,
    ;     ;     height: extendedframeboundsbottom - extendedframeboundstop
    ;     ; }


    ; }

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

GetMouseMonitor() {
    MouseGetPos(&x, &y)
    return GetMonitorAt(x, y)
}

GetWindowIcon(hwnd) {
    if (!WinExist("ahk_id " hwnd)) {
        return ""
    }
    try {
        processname := WinGetProcessName("ahk_id " hwnd)
    } catch {
        processname := "?"
    }


    static hShell32 := DllCall("LoadLibrary", "Str", "shell32.dll", "Ptr")

    ; Try WM_GETICON first
    ; try if hIcon := SendMessage(0x7F, 0, 0, , "ahk_id " hwnd)  ; WM_GETICON ICON_SMALL
    try {

        try if hIcon := SendMessage(0x7F, 1, 0, , "ahk_id " hwnd)  ; WM_GETICON ICON_BIG
            return "HICON:" hIcon

    }
    ; Try class icons
    try {

        if hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr")  ; GCL_HICONSM
            return "HICON:" hIcon

    }
    try {

        if hIcon := GetLargestUWPLogoPath(hwnd)
            return hIcon

    }
    return ""

    ; tysm https://www.autohotkey.com/boards/viewtopic.php?t=127727
    GetLargestUWPLogoPath(hwnd) {
        global iconCache
        ; MsgBox("looking for uwp path")
        if (iconCache.Has(hwnd)) {
            ; we've already fetched this application's icon, so let's not do it again :)
            WriteLog("uwp icon cache hit!")
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

            test(type) {
                if (type > besttype) {
                    best := A_LoopFilePath
                    besttype := type
                }
            }

            loop files Dir "\" "*.png" {
                if RegExMatch(A_LoopFileName, ".*\.targetsize-256\." . Extension . "$") {
                    type := 256

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.targetsize-96\." . Extension . "$") {
                    type := 96
                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.targetsize-72\." . Extension . "$") {
                    type := 72

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.targetsize-48\." . Extension . "$") {
                    type := 48

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.targetsize-36\." . Extension . "$") {
                    type := 36

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.targetsize-32\." . Extension . "$") {
                    type := 32
                    test(type)

                }
                ; these are bad and don't fit in the frame correctly..
                if RegExMatch(A_LoopFileName, ".*\.scale-400\." . Extension . "$") {
                    type := 4

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.scale-200\." . Extension . "$") {
                    type := 2

                    test(type)
                }
                if RegExMatch(A_LoopFileName, ".*\.scale-100\." . Extension . "$") {
                    type := 1

                    test(type)
                }
            }

            ; MsgBox(best)
            return best
        }
    }
}
