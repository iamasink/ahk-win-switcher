#Requires AutoHotkey v2.0
#SingleInstance Force

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

#DllLoad 'dwmapi'

#include Peep.v2.ahk

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

WatchForChildWindows(0)

F9:: {
    ; Close the active window
    hwnd := WinActive("A")
    window := hwnd
    process := WinGetProcessName("ahk_id " hwnd)
    WinClose(hwnd)

    ; Monitor for new child windows
    Sleep(500)
    child := WatchForChildWindows(hwnd)

    MsgBox("!!" child)
}

WatchForChildWindows(parenthwnd := 0) {
    static knownWindows := Map()
    idList := WinGetList()


    for hwnd in idList {
        if (!knownWindows.Has(hwnd)) {
            knownWindows[hwnd] := true

            if (parenthwnd == 0) {
                return
            }

            ; Get window title and class
            title := WinGetTitle(hwnd)
            class := WinGetClass(hwnd)
            owner := DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr") ; GW_OWNER = 4
            ownerStatus := owner ? "Yes" : "No"
            processName := WinGetProcessName("ahk_id " hwnd)


            msg :=
                "New window:`n"
                . "HWND: " hwnd "`n"
                . "Title: " title "`n"
                . "Class: " class "`n"
                . "Has Owner: " ownerStatus "`n"
                . "Process Name: " processName

            ToolTip(msg)
            ; Sleep a bit so tooltip doesn't vanish instantly
            Sleep(500)
            ToolTip()

            if (hwnd == parenthwnd) {
                return hwnd
            }
            if (processName == WinGetProcessName("ahk_id " parenthwnd)) {
                return hwnd
            }
            return 0

        }
    }
}

#HotIf WinActive(A_ScriptName " ahk_exe Code.exe")
~^s:: {
    ToolTip("Reloading " A_ScriptName ".", A_ScreenWidth / 2, A_ScreenHeight / 2)
    Sleep(250)
    Reload()
}
