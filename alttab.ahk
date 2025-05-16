#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")

#DllLoad 'dwmapi'

#Include Peep.v2.ahk

InstallKeybdHook(1)

; possibly prevent taskbar flashing on win activate
#WinActivateForce

; main config options
; the background colour of the main switcher window
global BACKGROUND_COLOUR := "202020"
; the colour of the selected window highlight
global SELECTED_BACKGROUND_COLOUR := "ff8aec"
; the text colour of text and window titles
global TEXT_COLOUR := "ffffff"

global SELECTED_TEXT_COLOUR := "101010"

global DEBUG := true

; required to alt tab from admin windows, eg task manager
; suggested true, but false can be useful for debugging
global RUN_AS_ADMIN := !DEBUG
; true = show thumbnails, horizonal layout, false = no thumbnails, vertical layout
global USE_THUMBNAILS := true
; delay before showing the switcher, in ms
; if its too low, weird stuff happens.
; TODO: is this still an issue?
global SWITCHER_DELAY := 100
; how often the open switcher will update passively, in ms
global UPDATE_SPEED := 500


global SWITCHER_PADDING_LEFT := 10
global SWITCHER_PADDING_TOP := 10

global SWITCHER_ITEM_PADDING_WIDTH := 5

global SWITCHER_ITEM_MAXHEIGHT := 250
global SWITCHER_ITEM_MAXWIDTH := SWITCHER_ITEM_MAXHEIGHT * 2

; 0 - 1
global SWITCHER_MAXSCREENWIDTH_PERCENTAGE := 0.8


global OFFSET_TEXT_X := 40
global OFFSET_TEXT_Y := 8
global OFFSET_LOGO_X := 5
global OFFSET_LOGO_Y := 1
global OFFSET_THUMBNAIL_X := 1
global OFFSET_THUMBNAIL_Y := 32 + OFFSET_LOGO_Y
global OFFSET_BACKGROUND_X := 0
global OFFSET_BACKGROUND_Y := 0

; alt q
global ENABLE_MOUSEMOVE_KEYBIND := true


; 0= auto, otherwise monitor index
; global displayOnMonitor := 2 ; currently not used

; if not admin, start as admin
; taken from https://www.autohotkey.com/boards/viewtopic.php?p=523250#p523250

if (RUN_AS_ADMIN && !A_IsAdmin) {
    try {
        ; MsgBox("Running as admin...")
        Run("*RunAs `"" A_ScriptFullPath "`"")
        ; wait, so that the script doesnt continue running and instead restarts as admin (hopefully) before this runs out, otherwise it will just close.
        Sleep(10000)
        MsgBox("Couldn't run " A_ScriptName " as admin! Exiting..")
        Sleep(5000)
        ExitApp()
    }
    catch {
        MsgBox("Couldn't run " A_ScriptName " as admin! Exiting..")
        Sleep(5000)
        ExitApp()
    }
}

global altDown := false
global tabPressed := false
global altPressTime := 0
global switcherShown := false
global listOfWindows := []
global selectedIndex := 1
global lastIndex := 2
global iconCache := Map()

global switcherWidth := 500
global switcherHeight := 0


global selectedMonitor := 0
; prevent weird race conditions when updating the gui, especially when creating thumbnails
global guiUpdateLock := false

; maybe realtime is overkill
ProcessSetPriority("R")


; setup the gui
switcherGui := Gui()
switcherGui.BackColor := BACKGROUND_COLOUR
switcherGui.Opt("-Caption +ToolWindow +Resize -DPIScale")
switcherGui.Opt("+AlwaysOnTop ")
; maybe reduce flickering
; switcherGui.Opt("+0x02000000") ; WS_EX_COMPOSITED &
; switcherGui.Opt("+0x00080000") ; WS_EX_LAYERED

switcherGuiSlots := Map()

BuildWindowList()
UpdateControls()


f11:: {
    global selectedMonitor
    selectedMonitor := GetMouseMonitor()
    ; MsgBox("monitor: " selectedMonitor)
    BuildWindowList(selectedMonitor)
    UpdateControls()
    ShowSwitcher()
}

f12:: {
    HideSwitcher()
}
f10:: {
    ; change the text for a window with current ms

    ; switcherGuiSlots[1].text.Text := "test" A_ScriptName " " A_TickCount
    ; switcherGuiSlots[1].text.GetPos(&x, &y, &w, &h)
    ; switcherGuiSlots[1].text.Move(x, y, w * 2,)
    ; Peep(switcherGuiSlots[1])
    BuildWindowList(1)


    UpdateControls()
}

UpdateSelected() {
    global listOfWindows, switcherGuiSlots, selectedIndex, lastIndex, switcherShown

    ; find the hwnd in switcherGuiSlots

    ; first remove old stuff
    ; windowLookup := Map()
    ; for index, hwnd in listOfWindows
    ;     windowLookup[ hwnd ] := true

    ; for hwnd, wininfo in switcherGuiSlots
    ; {
    ;     if !windowLookup.Has(hwnd)
    ;     {
    ;         wininfo.Destroy()
    ;     }
    ; }

    for index, hwnd in listOfWindows {
        try {
            ; MsgBox("hwnd: " hwnd "`nindex: " index)

            ; set if selected or not
            switcherslot := switcherGuiSlots[hwnd]
            if (index == selectedIndex) {
                switcherslot.SetSelected(true)
            } else {
                switcherslot.SetSelected(false)
            }

            ; if (index == selectedIndex +1) {
            ;     switcherslot.Redraw()
            ; }
        }

    }
}

GetHWNDFromIndex(index) {
    global listOfWindows
    return listOfWindows[index]

    ; old map stuff remove later
    ; for hwnd, i in listOfWindows {
    ;     if (i == index) {
    ;         return hwnd
    ;     }
    ; }
    ; return -1
}


#HotIf
*~LAlt:: {
    global altDown, altPressTime, showGUI, tabPressed, lastupdate
    ; altDown := true
    showGUI := false
    tabPressed := false

    altPressTime := A_TickCount
    lastupdate := altPressTime
    altDown := true

    ; ToolTip("alt down`n " tabPressed, , , 2)
    SetTimer(AltDownLoop, -1)
}

AltDownLoop() {
    global altDown, altPressTime, showGUI, tabPressed, switcherShown, selectedIndex, lastIndex, listOfWindows, selectedMonitor, SWITCHER_DELAY, lastupdate
    ; tooltip("alt down`n" tabPressed "`n" selectedIndex "`n" lastIndex "`n" windows.Length "`n" showMonitor)
    ; tabtext := tabPressed ? "tab pressed" : "no tab pressed"
    ; ToolTip("Alt is being held down.`nTab Status: " tabtext "`nSelected Index: " selectedIndex "`nLast Index: " lastIndex "`nNumber of Windows: " windows.Length "`nMonitor: " showMonitor "`nAlt Press Time: " altPressTime, , , 2)
    ; altDown := GetKeyState("LAlt", "P")
    if (GetKeyState("LAlt", "P")) {
        altDown := true
    } else {
        altDown := false
    }


    if (altDown) {
        if (tabPressed) {
            ; update the window list
            BuildWindowList(selectedMonitor)
            if (altPressTime + SWITCHER_DELAY < A_TickCount) {
                if (!switcherShown) {
                    UpdateControls()
                    ; UpdateSelected(selectedIndex)
                    ChangeSelectedIndex(selectedIndex)
                    ShowSwitcher()
                } else {
                    ;periodically update switcher
                    if (A_TickCount - lastupdate > UPDATE_SPEED) {
                        UpdateControls()
                        ; ToolTip("hi")
                        lastupdate := A_TickCount
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
                HideSwitcher()
            }
            ; tempwindowstring := ""
            ; for index, w in windows {
            ;     tempwindowstring := tempwindowstring w.title "`n"
            ; }
            ; ToolTip("focus index " selectedIndex "`n windows: " tempwindowstring)

            hwnd := GetHWNDFromIndex(selectedIndex)
            if (hwnd != -1) {
                FocusWindow(hwnd)
            } else {
                MsgBox("no hwnd",)
            }
            selectedIndex := 1
            lastIndex := 1
            selectedMonitor := 0
        } else {
            ; ToolTip("no tab", , , 10)
        }
    }
}

#HotIf altDown
*Tab:: {
    global tabPressed
    tabPressed := true
    ; UpdateControls()
    ChangeSelectedIndexBy(1)
}

*+Tab:: {
    global tabPressed
    tabPressed := true
    ; UpdateControls()
    ChangeSelectedIndexBy(-1)
}

*o:: {
    global tabPressed
    tabPressed := true
    ; UpdateControls()
    ChangeSelectedIndexBy(1)
}

ChangeSelectedIndexBy(change) {
    global selectedIndex
    selectedIndex += change
    if (selectedIndex > listOfWindows.Length) {
        selectedIndex := 1
    } else if (selectedIndex < 1) {
        selectedIndex := listOfWindows.Length
    }

    BuildWindowList(selectedMonitor)
    ; dont run this if the switcher isn't shown! or it will try do it twice on first alt+tab
    if (switcherShown) {
        ; update the controls for removed windows, resized windows etc.
        UpdateControls()
    }
    UpdateSelected()
    ; switcherGui.Show()
}

*`:: {
    global selectedMonitor, selectedIndex, tabPressed
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

+`:: {
    global selectedMonitor, selectedIndex, tabPressed
    tabPressed := true
    HandleTilde(-1)
}

#HotIf altDown && tabPressed

*1:: HandleNumber(1)
*2:: HandleNumber(2)
*3:: HandleNumber(3)
*4:: HandleNumber(4)
*5:: HandleNumber(5)
*6:: HandleNumber(6)
*7:: HandleNumber(7)
*8:: HandleNumber(8)
*9:: HandleNumber(9)
*0:: HandleNumber(0)

*WheelDown:: ChangeSelectedIndexBy(1)
*WheelUp:: ChangeSelectedIndexBy(-1)


*q:: {
    if (!ENABLE_MOUSEMOVE_KEYBIND)
        return

    ; jump mouse to active win
    global selectedIndex, listOfWindows

    if (listOfWindows.Length > 0) {
        win := listOfWindows[selectedIndex]
    } else {
        win := WinActive("A")
    }

    MoveMouseToWindowCenter(win)
}

*w:: {
    CloseWindowAndUpdate(listOfWindows[selectedIndex])
}

CloseWindowAndUpdate(hwnd) {
    global listOfWindows, selectedIndex, lastIndex, switcherGui
    ; close the window
    try {
        WinClose("ahk_id " hwnd)
    }


    BuildWindowList(selectedMonitor)
    if (selectedIndex > listOfWindows.Length) {
        ChangeSelectedIndex(listOfWindows.Length)
    } else if (selectedIndex < 1) {
        ChangeSelectedIndex(1)
    }

    ; update controls cuz therell be a gap
    UpdateControls()
    ; update the now selected control
    UpdateSelected()


}

MoveMouseToWindowCenter(hwnd) {

    ; with mouse positions, its different to thumbnail stuff, override scaling to 100%
    pos := GetWindowNormalPos(hwnd, 1)
    x := pos.left
    y := pos.top
    w := pos.width
    h := pos.height

    ; WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    centerX := x + (w // 2)
    centerY := y + (h // 2)

    BetterMouseMove(centerX, centerY, 5)
}

; improved MouseMove() function
BetterMouseMove(x, y, steps := 50, sleepTime := 2) {
    ; Smoothly animate mouse movement to the position
    MouseGetPos(&mousex, &mousey)
    stepX := (x - mousex) / steps
    stepY := (y - mousey) / steps

    loop steps {
        DllCall("SetCursorPos", "Int", mousex += stepX, "Int", mousey += stepY)
        Sleep(sleepTime)
    }
    ; Ensure the mouse ends up exactly at the center
    DllCall("SetCursorPos", "Int", x, "Int", y)

}

; rebind scroll click to right click
*MButton::RButton
#HotIf

HandleTilde(change) {
    global selectedMonitor, selectedIndex
    selectedMonitor += change
    monitorCount := MonitorGetCount()
    if selectedMonitor > monitorCount {
        selectedMonitor := 1
    }
    if selectedMonitor < 1 {
        selectedMonitor := monitorCount
    }

    selectedIndex += change
    if (selectedIndex > listOfWindows.Length) {
        selectedIndex := 1
    } else if (selectedIndex < 1) {
        selectedIndex := listOfWindows.Length
    }


    ; ToolTip("change: " change "`n" selectedMonitor "`n" tabPressed "`n" )
    BuildWindowList(selectedMonitor)
    ChangeSelectedIndex(1)

    if (switcherShown) {
        UpdateControls()
    }

    ; UpdateSelected()

    ; ChangeSelectedIndexBy(1)
    ; ChangeSelectedIndexBy(-1)


    ; BuildWindowList(selectedMonitor)
    ; dont run this if the switcher isn't shown! or it will try do it twice on first alt+tab
    if (switcherShown) {
        ; update the controls for removed windows, resized windows etc.
        UpdateControls()
    }
    ; UpdateSelected()
    ; switcherGui.Show()


    UpdateSelected()


}

HandleNumber(num) {
    global selectedMonitor, selectedIndex, lastIndex, tabPressed, listOfWindows
    if (num > 0 && num < listOfWindows.Length) {
        ChangeSelectedIndex(num)
        ; selectedIndex := num
    } else {
        ChangeSelectedIndex(listOfWindows.Length)
        ; selectedIndex := listOfWindows.Length
    }
}


class windowInfo {


    hwnd := 0
    x := 0
    y := 0
    w := 0
    h := 0
    text := ""
    logo := ""
    background := ""

    textctl := ""
    logoctl := ""
    backgroundctl := ""

    thumbnailId := -1

    isSelected := false

    __New(hwnd, x, y, w, h) {
        this.hwnd := hwnd
        switcherGuiSlots[hwnd] := this


        this.backgroundctl := switcherGui.AddText(" c" BACKGROUND_COLOUR, "")
        this.backgroundctl.Opt("Background" BACKGROUND_COLOUR)


        this.text := WinGetTitle("ahk_id " hwnd)
        this.textctl := switcherGui.AddText("h16  c" TEXT_COLOUR, this.text)
        ; this.textctl.SetFont("", "Segoe UI")
        this.logo := GetWindowIcon(hwnd)
        this.logoctl := switcherGui.addPicture(" w32 h32", this.logo)

        this.isSelected := false

        this.backgroundctl.OnEvent("Click", TextClick.Bind(, , , , this))
        this.backgroundctl.OnEvent("ContextMenu", TextMiddleClick.Bind(, , , , this)) ; rightclick


        ; create thumbnail
        this.thumbnailId :=
            CreateThumbnail(
                this.hwnd,
                switcherGui.hwnd,
                x + OFFSET_THUMBNAIL_X,
                y + OFFSET_THUMBNAIL_Y,
                100,
                100
            )

        ; this sets the pos of everything and updates the x, y, w, h values :)
        ; this.SetPos(x, y, w, h)

        ; this.backgroundctl.Visible := true
        ; this.textctl.Visible := true
        ; this.logoctl.Visible := true


    }
    SetTitle(title) {
        this.text := title
        ; Peep(this)
        this.textctl.Text := title
        this.textctl.Redraw()
    }
    SetLogo(logo) {
        this.logo := logo
        this.logoctl.Value := logo
        this.logoctl.Redraw()
    }

    SetPos(x, y, w := 0, h := 0) {


        ; if (w == 0) {
        ;     w := 100
        ; } else {
        ;     w := w
        ; }
        ; if (h == 0) {
        ;     h := 50
        ; } else {
        ;     h := h
        ; }
        ; if (this.x == x && this.y == y && this.w == w && this.h == h) {
        ;     MsgBox("no change!")
        ;     return
        ; }

        if (this.x == x && this.y == y && this.w == w && this.h == h) {
            ; MsgBox("this doesn=t need to move! `n" this.x " " this.y " " x " " y)
            return
        }

        ; MsgBox("moving " this.hwnd " from " this.x " " this.y " to " x " " y " " w " " h)


        this.x := x
        this.y := y
        this.w := w
        this.h := h
        try {
            this.backgroundctl.Move(x + OFFSET_BACKGROUND_X, y + OFFSET_BACKGROUND_Y, w + OFFSET_THUMBNAIL_X + 1, h + OFFSET_THUMBNAIL_Y + 1)
            ; this.backgroundctl.Opt("Backgroundff00ff")
            this.logoctl.Move(x + OFFSET_LOGO_X, y + OFFSET_LOGO_Y)
            this.textctl.Move(x + OFFSET_TEXT_X, y + OFFSET_TEXT_Y, this.w - OFFSET_TEXT_X, 16)
            this.Redraw()

            UpdateThumbnail(
                this.thumbnailId,
                x + OFFSET_THUMBNAIL_X,
                y + OFFSET_THUMBNAIL_Y,
                w,
                h)
        }

    }

    SetSelected(isSelected) {
        if (this.isSelected == isSelected) {
            return
        }

        bgColour := ""
        textColour := ""

        if (isSelected) {
            this.isSelected := true

            bgColour := SELECTED_BACKGROUND_COLOUR
            textColour := SELECTED_TEXT_COLOUR

            ;             this.backgroundctl.Opt("Background" SELECTED_BACKGROUND_COLOUR)
            ;             this.logoctl.Opt("Background" SELECTED_BACKGROUND_COLOUR)
            ;             this.textctl.Opt("Background" SELECTED_BACKGROUND_COLOUR)
            ;             ; this will redraw the text
            ;             this.textctl.Opt("c" SELECTED_TEXT_COLOUR)
            ; ; redraw these by changing their colour property, this doesnt actually change anything
            ; ; but does trick it into redrawing.

            ;             this.backgroundctl.Opt("c" SELECTED_TEXT_COLOUR)

            ;             this.logoctl.Opt("c" SELECTED_TEXT_COLOUR)
        } else {
            this.isSelected := false

            bgColour := BACKGROUND_COLOUR
            textColour := TEXT_COLOUR
        }
        this.backgroundctl.Opt("Background" bgColour)
        this.logoctl.Opt("Background" bgColour)
        this.textctl.Opt("Background" bgColour)
        ; this will redraw the text
        this.textctl.Opt("c" textColour)
        ; redraw these by changing their colour property, this doesnt actually change anything
        ; but does trick it into redrawing, seemingly more seamlessly than using .Redraw()
        this.backgroundctl.Opt("c" textColour)
        this.logoctl.Opt("c" textColour)
        ; this.Redraw()
    }


    Redraw() {
        this.backgroundctl.Redraw()
        this.textctl.Redraw()
        this.logoctl.Redraw()
    }


    Destroy() {
        ; destroy the thumbnail
        ; MsgBox("destroying thumbnail " this.thumbnailId "`nif you didnt close a window, you might've done something bad. ")

        ; sometimes this errors, sometimes its needed. dunno

        ; UpdateThumbnail(this.thumbnailId,0,0,0,0,0,0)
        try {


            this.backgroundctl.Visible := false
            this.logoctl.Visible := false
            this.textctl.Visible := false
            ; this.Redraw()
            try {
                DllCall('dwmapi\DwmUnregisterThumbnail', 'Ptr', this.thumbnailId, 'HRESULT')
            }
            switcherGuiSlots.Delete(this.hwnd)
        }
    }
}

UpdateControls() {
    global switcherGuiSlots, listOfWindows, selectedIndex, lastIndex
    global switcherGui, selectedMonitor, switcherWidth, switcherHeight

    ; y := 50

    ; first remove any old windows
    ; for hwnd, mywindowInfo in switcherGuiSlots {
    ;     if !listOfWindows.Has(hwnd) {
    ;         ; MsgBox("destroying " hwnd)
    ;         mywindowInfo.Destroy()
    ;     }
    ; }

    ; for _, win in listOfWindows {
    ;     if (win.hwnd = hwnd) {
    ;         found := true
    ;         break
    ;     }
    ; }
    ; if !found {
    ;     Peep(listOfWindows, switcherGuiSlots, wininfo, hwnd)
    ;     wininfo.Destroy()
    ; }

    ; first remove unneeded windows
    windowLookup := Map()
    for index, hwnd in listOfWindows
        windowLookup[hwnd] := true

    ; Peep(windowLookup)
    ; Peep(switcherGuiSlots)

    ; sometimes this doesnt function correctly. IDK
    for hwnd, wininfo in switcherGuiSlots {
        if !windowLookup.Has(hwnd) {
            ; if (DEBUG) MsgBox("destroying. this is bad unless you closed a window")
            wininfo.Destroy()
        }
    }


    ; Peep(windowLookup)


    row := 0
    rowWidth := 0
    lastx := SWITCHER_PADDING_LEFT
    switcherWidth := 0
    switcherHeight := 0

    for index, hwnd in listOfWindows {
        ; we want to limit both width and height to an extent
        ; height should be the main thing / hard limit for simplicity


        ; get the windows size for aspect ratio stuffs
        ; this could possibly be done with dwmapi\DwmQueryThumbnailSourceSize


        method := 1
        if method = 0 {
            ; this doewsnt work correctly, wrong index vs thumbnail id
            pSize := Buffer(8, 0)

            result := DllCall('dwmapi\DwmQueryThumbnailSourceSize', 'Ptr', index, 'Ptr', pSize.Ptr, 'UInt')


            sourceW := NumGet(pSize, 0, 'Int')
            sourceH := NumGet(pSize, 4, 'Int')
        } else {
            windowSize := GetWindowNormalPos(hwnd)
            sourceW := windowSize.width
            sourceH := windowSize.height
        }


        ; aspect ratio in terms of width = height * aspectratio
        ; so height = width / aspectratio
        aspectratio := (sourceW / sourceH)

        ; set size based on maxheight and aspect ratio
        h := Floor(SWITCHER_ITEM_MAXHEIGHT)
        w := Floor(h * aspectratio)


        ; check if width is too big
        if (w > SWITCHER_ITEM_MAXWIDTH) {
            ; instead set size based on maxwidth
            w := Floor(SWITCHER_ITEM_MAXWIDTH)
            h := Floor(w / aspectratio)
        }


        ; MsgBox("hwnd: " hwnd "`nindex: " index)
        y := SWITCHER_PADDING_TOP + (row * (SWITCHER_ITEM_MAXHEIGHT + OFFSET_THUMBNAIL_Y + 1))
        x := lastx
        lastx += w + SWITCHER_ITEM_PADDING_WIDTH
        rowWidth := lastx


        CreateOrUpdateControl(hwnd, x, y, w, h)
        if (y > switcherHeight) {
            switcherHeight := y
        }
        if (lastx > switcherWidth) {
            switcherWidth := lastx
        }

        if (rowWidth >= A_ScreenWidth * (SWITCHER_MAXSCREENWIDTH_PERCENTAGE)) {
            row += 1
            lastx := SWITCHER_PADDING_LEFT

        }

    }

}

CreateOrUpdateControl(hwnd, x, y, w, h) {
    global switcherGuiSlots
    if (switcherGuiSlots.Has(hwnd)) {
        ; msgbox("updating " hwnd)
        if (switcherGuiSlots[hwnd].x = x &&
            switcherGuiSlots[hwnd].y = y &&
            switcherGuiSlots[hwnd].w = w &&
            switcherGuiSlots[hwnd].h = h
        ) {
            ; MsgBox("skipping hwnd: " hwnd)
            ; ToolTip("skipping hwnd: " hwnd)

        } else {
            ; MsgBox("moving hwnd:" hwnd)
            ; title := WinGetTitle("ahk_id " hwnd)
            ; ToolTip("moving hwnd:" hwnd ", title: " title)
            switcherGuiSlots[hwnd].SetPos(x, y, w, h)
        }
    } else {
        ; msgbox("creating " hwnd)
        mywindowInfo := windowInfo(hwnd, x, y, w, h)
        mywindowInfo.SetPos(x, y, w, h)
    }
}

RedrawAll() {
    for hwnd in switcherGuiSlots {
        switcherGuiSlots[hwnd].Redraw()
    }
}

;; Create a thumbnail for the given window
; Parameters:
; - windowHwnd: The handle of the source window to create a thumbnail for
; - thumbnailHwnd: The handle of the window to display the thumbnail in
; - guiPosX: the x position of the thumbnail on the GUI
; - guiPosY: the y position of the thumbnail on the GUI
; - sourceW: the width of the source window
; - sourceH: the height of the source window
; - thumbW: the width of the thumbnail
; - thumbH: the height of the thumbnail
; Returns: The thumbnail ID
CreateThumbnail(windowHwnd, thumbnailHwnd, guiPosX, guiPosY, thumbW, thumbH, sourceW := 0, sourceH := 0) {

    ; MsgBox("creating thumbnail... `nwindowHwnd: " windowHwnd "`nthumbnailHwnd: " thumbnailHwnd "`nguiPosX: " guiPosX "`nguiPosY: " guiPosY "`nsourceW: " sourceW "`nsourceH: " sourceH "`nthumbW: " thumbW "`nthumbH: " thumbH)

    DllCall('dwmapi\DwmRegisterThumbnail', 'Ptr', thumbnailHwnd, 'Ptr', windowHwnd, 'Ptr*', &hThumbnailId := 0, 'HRESULT')

    ; UpdateThumbnail(hThumbnailId, guiPosX, guiPosY, thumbW, thumbH, sourceW := 0, sourceH := 0)

    return hThumbnailId
}

;; Update a thumbnail
; Parameters:
; - thumbNailId: The ID of the thumbnail to update
; - guiPosX: the x position of the thumbnail on the GUI
; - guiPosY: the y position of the thumbnail on the GUI
; - thumbW: the width of the thumbnail
; - thumbH: the height of the thumbnail
; - sourceW: the width of the source window
; - sourceH: the height of the source window
; Returns: HRESULT
UpdateThumbnail(thumbNailId, guiPosX, guiPosY, thumbW, thumbH, sourceW := 0, sourceH := 0) {
    ; MsgBox("updating thumbnail... `nthumbNailId: " thumbNailId "`nguiPosX: " guiPosX "`nguiPosY: " guiPosY "`nsourceW: " sourceW "`nsourceH: " sourceH "`nthumbW: " thumbW "`nthumbH: " thumbH)

    ; use DwmQueryThumbnailSourceSize to get the source size
    if (sourceW = 0 && sourceH = 0) {

        pSize := Buffer(8, 0)

        result := DllCall('dwmapi\DwmQueryThumbnailSourceSize', 'Ptr', thumbNailId, 'Ptr', pSize.Ptr, 'UInt')


        sourceW := NumGet(pSize, 0, 'Int')
        sourceH := NumGet(pSize, 4, 'Int')
        ; MsgBox("sourceW: " sourceW "`nsourceH: " sourceH)
    }


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
        'Int', 8, ; start x of source
        'Int', 0, ; start y of source
        'Int', sourceW + 1, ; x2 of source?
        'Int', sourceH, ;  y2 of source?
        Properties := Buffer(45, 0)
    )
    NumPut('UInt', true, Properties, 37)

    return DllCall('dwmapi\DwmUpdateThumbnailProperties', 'Ptr', thumbNailId, 'Ptr', Properties, 'HRESULT')
}

GetThumbnailSize(thumbnailId) {

    pSize := Buffer(8, 0)

    result := DllCall('dwmapi\DwmQueryThumbnailSourceSize', 'Ptr', thumbNailId, 'Ptr', pSize.Ptr, 'UInt')


    sourceW := NumGet(pSize, 0, 'Int')
    sourceH := NumGet(pSize, 4, 'Int')
    ; MsgBox("sourceW: " sourceW "`nsourceH: " sourceH)
    return { w: sourceW, h: sourceH }

}


BuildWindowList(monitorNum := MonitorGetPrimary()) {
    if (monitorNum = 0) {
        monitorNum := MonitorGetPrimary()
    }

    global listOfWindows
    listOfWindows := []
    DetectHiddenWindows(false)
    static WS_POPUP := 0x80000000, WS_CHILD := 0x40000000
    static WS_EX_TOOLWINDOW := 0x80, WS_EX_APPWINDOW := 0x40000
    static GW_OWNER := 4, DWMWA_CLOAKED := 14
    scriptPID := ProcessExist()
    listindex := 1

    for index, hwnd in WinGetList() {

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

        winpos := GetWindowNormalPos(hwnd)
        centerX := winpos.left + (winpos.width // 2)
        centerY := winpos.top + (winpos.height // 2)

        winMon := GetMonitorAt(centerX, centerY)
        if (winMon != monitorNum)
            continue

        ; if !existingHWNDs.Has(hwnd) {
        ; windows.Push({ hwnd: hwnd, title: title })
        ; set the order it should be in the list
        ; listOfWindows[hwnd] := listindex
        listOfWindows.Push(hwnd)
        listindex++
        ; existingHWNDs.Set(hwnd, true)
        ; }
    }
}

ShowSwitcher() {
    global guiUpdateLock, switcherShown
    global switcherWidth, switcherHeight
    switcherShown := true
    if (guiUpdateLock) {
        return
    }
    guiUpdateLock := true
    w := switcherWidth + 50
    h := switcherHeight + 300
    x := (A_ScreenWidth - w) // 2
    y := (A_ScreenHeight - h) // 2


    ; prevent flashing
    ; switcherGui.Show("x10000 y10000 w" w " h" h)
    ; Sleep(100)

    switcherGui.AddText(, "monitor: " selectedMonitor)
    switcherGui.Show("w" w " h" h " x" x " y" y)
    ; switcherGui.Opt()


    guiUpdateLock := false
}

TextClick(ctl := '', index := 1, text := '', idk := '', ctl2 := 0) {
    global selectedIndex, altDown, listOfWindows, lastIndex, tabPressed
    ; MsgBox("hi " ctl2.hwnd)

    ; HideSwitcher()
    ; set the index then act as if alt was released
    ; selectedIndex := index
    ChangeSelectedIndex(index)
    tabPressed := false
    altDown := false
    HideSwitcher()
    selectedIndex := 2
    if (listOfWindows.Length > 0) {
        FocusWindow(ctl2.hwnd)
    } else {
        MsgBox("Bad")
    }
}

TextMiddleClick(ctl, index, text, idk := "", ctl2 := 0, *) {
    global selectedIndex, altDown
    ; close window from hwnd
    ; WinClose("ahk_id " ctl2.hwnd)

    ; ; we could destroy the control here, but some windows won't close from just one winclose, so its a bit slower but more reliable visual feedback
    ; ; update selected index, should it be now invalid
    ; if (selectedIndex > listOfWindows.Length) {
    ;     selectedIndex := listOfWindows.Length
    ; } else if (selectedIndex < 1) {
    ;     selectedIndex := 1
    ; }

    ; UpdateControls()

    CloseWindowAndUpdate(ctl2.hwnd)


    ; TODO: close window and update list
}


ChangeSelectedIndex(index) {
    global selectedIndex, lastIndex
    lastIndex := selectedIndex
    selectedIndex := index
}


HideSwitcher() {
    global switcherGui, switcherShown
    ; switcherGui.Minimize()
    switcherGui.Show("Hide")
    switcherShown := false
}

FocusWindow(hwnd) {
    ; WinActivate("ahk_id " hwnd)
    ; try DllCall("SetForegroundWindow", "Ptr", hwnd)

    if !WinExist("ahk_id " hwnd)
        return false

    WinActivate("ahk_id " hwnd)
    ; Sleep(10)
    ; activate with dll
    ; nvm this is not needed
    ; DllCall("SetForegroundWindow", "Ptr", hwnd)

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

    state := WinGetMinMax("ahk_id" hwnd)


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
