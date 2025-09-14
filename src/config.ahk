#Requires AutoHotkey v2.0

; #endregion ====================================================================
; #region MARK:                         config
; ===============================================================================
; main config options

;
global DEBUG := false

; required to alt tab from admin windows, eg task manager
; suggested true, but false can be useful for debugging
global RUN_AS_ADMIN := !DEBUG


; the background colour of the main switcher window
global BACKGROUND_COLOUR := "202020"
; the colour of the selected window highlight
global SELECTED_BACKGROUND_COLOUR := "ff8aec"
; the text colour of text and window titles
global TEXT_COLOUR := "ffffff"

global SELECTED_TEXT_COLOUR := "101010"

; true = show thumbnails, horizonal layout, false = no thumbnails, vertical layout
global USE_THUMBNAILS := true ; unused
; delay before showing the switcher, in ms
; TODO: make more reliable when higher delay
global SWITCHER_DELAY := 100
; how often the open switcher will update passively, in ms
; to catch size changes, title changes, logo changes, etc.
global UPDATE_SPEED := 500

; how often to run the alt loop.
; note this doesnt affect how fast alt+tab works, only the visuals
global ALT_CHECK_DELAY := 10


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

; alt e bind
global ENABLE_MOUSEMOVE_KEYBIND := true