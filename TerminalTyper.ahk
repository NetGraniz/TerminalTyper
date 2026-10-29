#Requires AutoHotkey v2.0
#SingleInstance Force

; TerminalTyper for AutoHotkey v2 — standalone native interface.
; Native Windows input controls with GDI+ antialiased rounded framing.
; No icons, PNG files, extracted assets or external script dependencies.
SetKeyDelay(0, 0)

isTyping := false
stopRequested := false
typingChars := []
typingIndex := 1
typingPhase := ""
typingTarget := 0
typingStartAt := 0
nextCharAt := 0
lastCountShown := -1
charDelay := 35
enterDelay := 250
startDelay := 5000

roundedControls := []
gdipToken := 0
fontFamily := 0
StartGraphics()

; Normal non-topmost window with a custom header. No external .ico.
mainGui := Gui("-Caption", "TerminalTyper")
mainGui.BackColor := "F4F8FE"
mainGui.MarginX := 0
mainGui.MarginY := 0

; Pale blue title area.
headerBackground := mainGui.AddText("x0 y0 w724 h116 BackgroundE5F2FF")
mainGui.AddText("x0 y115 w724 h2 BackgroundB9D5F0")
mainGui.SetFont("s20 Bold c284D73", "Segoe UI")
titleControl := mainGui.AddText("x32 y25 w540 h43 BackgroundTrans", "TerminalTyper")
mainGui.SetFont("s10 c6484A9 Norm", "Segoe UI")
subtitleControl := mainGui.AddText("x34 y73 w550 h26 BackgroundTrans", "Type into a browser-based terminal")

; Clickable GDI+ controls: Windows won't add its rectangular button border.
minimizeButton := AddStyledButton(631, 29, 33, 32, "−", "F1F7FE", "B8D5F0", "4D7CA6", (*) => mainGui.Minimize(), 12)
closeButton := AddStyledButton(674, 29, 33, 32, "×", "F1F7FE", "B8D5F0", "4D7CA6", (*) => ExitApp(), 12)

mainGui.SetFont("s11 Bold c315B84", "Segoe UI")
mainGui.AddText("x42 y134 w630 h26 BackgroundTrans", "TEXT TO TYPE")
mainGui.SetFont("s9.5 Norm c6D8CAB", "Segoe UI")
mainGui.AddText("x42 y167 w637 h29 BackgroundTrans", "Load a file or paste text. Characters are sent as simulated keystrokes.")

; The frame is painted into a memory bitmap with antialiased rounded corners.
AddRoundedPanel(38, 203, 648, 209, "BFD8F1", "F4F8FE", 18, 2)
mainGui.SetFont("s10 Norm c365F86", "Consolas")
editor := mainGui.AddEdit("x52 y218 w618 h179 WantTab +VScroll -Border -E0x200 BackgroundF4F8FE", "")

; Three uniform numeric inputs and perfectly centered labels.
mainGui.SetFont("s9.5 Bold c41688E", "Segoe UI")
mainGui.AddText("x29 y424 w212 h23 Center BackgroundTrans", "Between keys (ms)")
mainGui.AddText("x251 y424 w222 h23 Center BackgroundTrans", "After Enter (ms)")
mainGui.AddText("x482 y424 w214 h23 Center BackgroundTrans", "Before typing (ms)")

AddRoundedPanel(68, 453, 134, 39, "BFD8F1", "F4F8FE", 15, 2)
AddRoundedPanel(295, 453, 134, 39, "BFD8F1", "F4F8FE", 15, 2)
AddRoundedPanel(522, 453, 134, 39, "BFD8F1", "F4F8FE", 15, 2)
mainGui.SetFont("s10 Norm c365F86", "Segoe UI")
charDelayEdit := mainGui.AddEdit("x77 y462 w116 h26 Number Center -Border -E0x200 BackgroundF4F8FE", "35")
enterDelayEdit := mainGui.AddEdit("x304 y462 w116 h26 Number Center -Border -E0x200 BackgroundF4F8FE", "250")
startDelayEdit := mainGui.AddEdit("x531 y462 w116 h26 Number Center -Border -E0x200 BackgroundF4F8FE", "5000")

; Render the status dot as a GDI+ bitmap so it remains circular after restore.
; Raise it slightly to match the visual center of the status text.
statusDot := mainGui.AddPicture("x43 y522 w14 h14 Disabled")
statusGraphics := BeginRoundedPaint(14, 14, 0xFFF4F8FE, &statusBitmap)
GradientRounded(statusGraphics, 1, 1, 12, 12, 6, 0xFF66CDBA, 0xFF3CAB96)
EndRoundedPaint(statusDot, statusGraphics, statusBitmap)
mainGui.SetFont("s9.5 Bold c3D7188", "Segoe UI")
mainGui.AddText("x65 y520 w235 h23 BackgroundTrans", "Ready to type")
mainGui.SetFont("s8.5 Norm c7795B5", "Segoe UI")
mainGui.AddText("x42 y543 w244 h21 BackgroundTrans", "F12 — stop typing")

uploadButton := AddStyledButton(337, 512, 158, 44, "Load File", "E1EFFC", "A8C9EB", "38638E", LoadTextFile)
startButton := AddStyledButton(510, 512, 177, 44, "Start Typing", "378EDA", "216FB8", "FFFFFF", StartTyping)

mainGui.OnEvent("Close", (*) => ExitApp())
Hotkey("F12", StopTyping)
HotIfWinActive("ahk_id " mainGui.Hwnd)
Hotkey("^o", LoadTextFile)
Hotkey("^Enter", StartTyping)
HotIfWinActive()

OnMessage(0x84, HeaderHitTest)      ; WM_NCHITTEST
OnMessage(0x201, HeaderMouseDown)   ; WM_LBUTTONDOWN, including text controls

mainGui.Show("w724 h577 Center")
for item in roundedControls
    RoundControl(item[1], item[2])
RoundControl(mainGui.Hwnd, 26)

AddRoundedPanel(x, y, w, h, borderColor, fillColor, radius, thickness := 2) {
    global mainGui
    picture := mainGui.AddPicture("x" x " y" y " w" w " h" h " Disabled")
    g := BeginRoundedPaint(w, h, 0xFFF4F8FE, &bitmap)
    ; A soft inset glow and a sharp, smooth outline, matching NordCursor.
    GradientRounded(g, 1, 1, w - 2, h - 2, radius
        , HexArgb(fillColor), HexArgb(fillColor), HexArgb(borderColor), thickness)
    OutlineRounded(g, 3, 3, w - 6, h - 6, Max(2, radius - 2), 0x60FFFFFF, 0.8)
    EndRoundedPaint(picture, g, bitmap)
}

StartGraphics() {
    global gdipToken, fontFamily
    startup := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, startup, 0)
    if DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdipToken, "Ptr", startup, "Ptr", 0)
        throw Error("Unable to initialize Windows GDI+.")
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI"
        , "Ptr", 0, "Ptr*", &fontFamily)
}

BeginRoundedPaint(w, h, background, &bitmap) {
    bitmap := 0
    graphics := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h
        , "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", graphics, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", background)
    return graphics
}

EndRoundedPaint(picture, graphics, bitmap) {
    imageHandle := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap
        , "Ptr*", &imageHandle, "UInt", 0xFFF4F8FE)
    picture.Value := "HBITMAP:*" imageHandle
    DllCall("gdi32\DeleteObject", "Ptr", imageHandle)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
}

HexArgb(rgb) {
    return 0xFF000000 | Integer("0x" rgb)
}

GradientRounded(graphics, x, y, width, height, radius, topColor, bottomColor
    , borderColor := 0, thickness := 1) {
    path := MakeRoundedPath(x, y, width, height, radius)
    area := Buffer(16, 0)
    NumPut("Float", x, "Float", y, "Float", width, "Float", height, area)
    brush := 0
    status := DllCall("gdiplus\GdipCreateLineBrushFromRect", "Ptr", area
        , "UInt", topColor, "UInt", bottomColor, "Int", 1, "Int", 0
        , "Ptr*", &brush)
    if (status || !brush)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", topColor, "Ptr*", &brush)
    DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    if borderColor
        StrokeRounded(graphics, path, borderColor, thickness)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

OutlineRounded(graphics, x, y, width, height, radius, color, thickness := 1) {
    path := MakeRoundedPath(x, y, width, height, radius)
    StrokeRounded(graphics, path, color, thickness)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

MakeRoundedPath(x, y, width, height, radius) {
    path := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
    diameter := radius * 2
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + width - diameter
        , "Float", y, "Float", diameter, "Float", diameter, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + width - diameter
        , "Float", y + height - diameter, "Float", diameter, "Float", diameter, "Float", 0, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x
        , "Float", y + height - diameter, "Float", diameter, "Float", diameter, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x
        , "Float", y, "Float", diameter, "Float", diameter, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    return path
}

StrokeRounded(graphics, path, color, thickness) {
    pen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", color, "Float", thickness
        , "Int", 2, "Ptr*", &pen)
    DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", path)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
}

AddStyledButton(x, y, w, h, caption, fill, outline, ink, callback, fontSize := 10) {
    global mainGui
    ; SS_NOTIFY (+0x100) makes the picture itself a reliable click target.
    btn := mainGui.AddPicture("x" x " y" y " w" w " h" h " +0x100")
    background := (caption = "×" || caption = "−") ? 0xFFE5F2FF : 0xFFF4F8FE
    graphics := BeginRoundedPaint(w, h, background, &bitmap)
    primary := fill = "378EDA"
    topColor := primary ? 0xFF4AA5E8 : 0xFFF5FAFF
    bottomColor := primary ? 0xFF287FCB : HexArgb(fill)
    radius := Min(20, (h - 2) / 2)
    GradientRounded(graphics, 1, 1, w - 2, h - 2, radius
        , topColor, bottomColor, HexArgb(outline), 1.4)
    OutlineRounded(graphics, 3, 3, w - 6, h - 6, Min(18, (h - 6) / 2)
        , 0x42FFFFFF, 0.7)
    CenterText(graphics, caption, w, h, fontSize * 1.34, HexArgb(ink))
    EndRoundedPaint(btn, graphics, bitmap)
    btn.OnEvent("Click", callback)
    return btn
}

CenterText(graphics, caption, w, h, fontSize, color) {
    global fontFamily
    font := 0, brush := 0, format := 0
    DllCall("gdiplus\GdipCreateFont", "Ptr", fontFamily, "Float", fontSize
        , "Int", 1, "Int", 2, "Ptr*", &font)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "Ptr*", &brush)
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x1000, "UShort", 0
        , "Ptr*", &format)
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", format, "Int", 1)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", format, "Int", 1)
    textArea := Buffer(16, 0)
    NumPut("Float", 0, "Float", 0, "Float", w, "Float", h, textArea)
    DllCall("gdiplus\GdipDrawString", "Ptr", graphics, "WStr", caption, "Int", -1
        , "Ptr", font, "Ptr", textArea, "Ptr", format, "Ptr", brush)
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", format)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
}

RoundControl(hwnd, diameter) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect)
        return
    width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    height := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    region := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0
        , "Int", width + 1, "Int", height + 1, "Int", diameter, "Int", diameter, "Ptr")
    if region && !DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", region, "Int", 1)
        DllCall("gdi32\DeleteObject", "Ptr", region)
}

HeaderHitTest(wParam, lParam, msg, hwnd) {
    global mainGui
    if (hwnd != mainGui.Hwnd)
        return
    point := Buffer(8)
    DllCall("user32\GetCursorPos", "Ptr", point)
    mx := NumGet(point, 0, "Int")
    my := NumGet(point, 4, "Int")
    mainGui.GetPos(&gx, &gy)
    if (mx >= gx && mx < gx + 620 && my >= gy && my < gy + 112)
        return 2 ; HTCAPTION — system moves the window.
}

HeaderMouseDown(wParam, lParam, msg, hwnd) {
    global mainGui, headerBackground, titleControl, subtitleControl
    if (hwnd != mainGui.Hwnd && hwnd != headerBackground.Hwnd
        && hwnd != titleControl.Hwnd && hwnd != subtitleControl.Hwnd)
        return
    point := Buffer(8)
    DllCall("user32\GetCursorPos", "Ptr", point)
    mx := NumGet(point, 0, "Int")
    my := NumGet(point, 4, "Int")
    mainGui.GetPos(&gx, &gy)
    if (mx < gx || mx >= gx + 620 || my < gy || my >= gy + 112)
        return
    DllCall("user32\ReleaseCapture")
    DllCall("user32\SendMessageW", "Ptr", mainGui.Hwnd, "UInt", 0xA1
        , "Ptr", 2, "Ptr", 0, "Ptr") ; WM_NCLBUTTONDOWN / HTCAPTION
    return 0
}

LoadTextFile(*) {
    global editor
    path := FileSelect(3, , "Select a text file", "Text files (*.txt; *.sh; *.pub; *.json; *.conf)")
    if (path = "")
        return
    try {
        editor.Value := FileRead(path, "UTF-8")
    } catch Error as err {
        MsgBox("Unable to open the file:`n" err.Message, "TerminalTyper", "Iconx")
    }
}

StartTyping(*) {
    global mainGui, editor, charDelayEdit, enterDelayEdit, startDelayEdit
    global isTyping, stopRequested, typingChars, typingIndex, typingPhase
    global typingStartAt, nextCharAt, lastCountShown
    global charDelay, enterDelay, startDelay

    if isTyping
        return
    payload := editor.Value
    if (payload = "") {
        MsgBox("Load a file or enter some text.", "TerminalTyper", "Icon!")
        return
    }
    if !(RegExMatch(charDelayEdit.Value, "^\d{1,4}$")
        && RegExMatch(enterDelayEdit.Value, "^\d{1,4}$")
        && RegExMatch(startDelayEdit.Value, "^\d{1,5}$")) {
        MsgBox("Enter whole-number delays in milliseconds (ms).", "TerminalTyper", "Icon!")
        return
    }
    if (Integer(startDelayEdit.Value) > 60000) {
        MsgBox("Start delay must be between 0 and 60000 ms.", "TerminalTyper", "Icon!")
        return
    }

    charDelay := Max(10, Min(1000, Integer(charDelayEdit.Value)))
    enterDelay := Max(50, Min(3000, Integer(enterDelayEdit.Value)))
    startDelay := Integer(startDelayEdit.Value)
    payload := StrReplace(StrReplace(payload, "`r`n", "`n"), "`r", "`n")
    typingChars := StrSplit(payload)
    typingIndex := 1
    typingPhase := "waiting"
    typingStartAt := A_TickCount + startDelay
    nextCharAt := 0
    lastCountShown := -1
    isTyping := true
    stopRequested := false
    mainGui.Hide()
    ShowTransmissionTip("Click the web terminal · starts in " startDelay " ms · F12 to stop")
    SetTimer(TransmissionTick, 5)
}

TransmissionTick() {
    global isTyping, stopRequested, typingPhase, typingChars
    global typingStartAt, typingTarget, nextCharAt, typingIndex
    global lastCountShown, charDelay, enterDelay, mainGui

    if !isTyping
        return
    if stopRequested {
        FinishTransmission("stopped")
        return
    }
    now := A_TickCount
    if (typingPhase = "waiting") {
        remain := Max(0, Ceil((typingStartAt - now) / 100) * 100)
        if (remain != lastCountShown) {
            ShowTransmissionTip("Click the web terminal · " remain " ms · F12 to stop")
            lastCountShown := remain
        }
        if (now < typingStartAt)
            return
        try {
            typingTarget := WinGetID("A")
        } catch Error as err {
            FinishTransmission("error", err.Message)
            return
        }
        if (typingTarget = mainGui.Hwnd) {
            FinishTransmission("error", "The terminal is not selected.")
            return
        }
        typingPhase := "typing"
        nextCharAt := now
        ToolTip()
    }
    if (now < nextCharAt)
        return
    if !WinActive("ahk_id " typingTarget) {
        FinishTransmission("stopped")
        return
    }
    if (typingIndex > typingChars.Length) {
        FinishTransmission("done")
        return
    }
    scheduledAt := nextCharAt
    char := typingChars[typingIndex]
    delay := charDelay
    try {
        if (char = "`n") {
            SendEvent("{Enter}")
            delay := enterDelay
        } else if (char = "`t") {
            SendEvent("{Tab}")
        } else {
            SendLiteralKey(char)
        }
    } catch Error as err {
        FinishTransmission("error", err.Message)
        return
    }
    typingIndex += 1
    nextCharAt := Max(scheduledAt + delay, A_TickCount + 1)
}

ShowTransmissionTip(message) {
    ToolTip(message, Max(0, A_ScreenWidth - 470), 45)
}

FinishTransmission(result, detail := "") {
    global isTyping, mainGui
    SetTimer(TransmissionTick, 0)
    ToolTip()
    isTyping := false
    mainGui.Show()
    if (result = "error")
        MsgBox("Typing error:`n" detail, "TerminalTyper", "Iconx")
    else if (result = "stopped")
        MsgBox("Typing stopped. Check the active window and try again.", "TerminalTyper")
}

SendLiteralKey(char) {
    switch char {
        case "{":
            SendEvent("{{}")
        case "}":
            SendEvent("{}}")
        case "^", "+", "!", "#":
            SendEvent("{" char "}")
        default:
            SendEvent(char)
    }
}

StopTyping(*) {
    global isTyping, stopRequested
    if isTyping
        stopRequested := true
}
