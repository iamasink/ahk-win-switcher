#Requires AutoHotkey v2.0

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
