# TerminalTyper

A lightweight AutoHotkey v2 utility that types prepared text into a browser-based terminal or another active Windows application, one keystroke at a time. Useful when a remote console does not support normal clipboard paste.

![TerminalTyper application screenshot](TerminalTyper_screenshot.png)



## Requirements

Windows 10 or 11 and [AutoHotkey v2](https://www.autohotkey.com/) are required. Download `TerminalTyper.ahk` and double-click it to start.

The application is a **single `.ahk` file**. It does not need separate icons, skins, PNG files, or third-party AutoHotkey libraries. The screenshot above is documentation only and is not required to run the program.

## How to use

Paste the text you want to transmit into the large editor, or select **Load File** to open a UTF-8 text file. The file dialog supports `.txt`, `.sh`, `.pub`, `.json`, and `.conf` files.

Adjust the delays, then select **Start Typing**. TerminalTyper hides its window and shows a short countdown. During that countdown, switch to the browser and click inside the intended terminal input area.

When the countdown ends, the program begins sending simulated keystrokes. Keep the target window focused until transmission finishes. If focus changes, typing stops to avoid sending text to the wrong application. After completion, the TerminalTyper window reappears.

## Delay settings

**Between keys (ms)** controls the interval between ordinary keystrokes. Default: **35 ms**. Effective range: **10–1000 ms**.

**After Enter (ms)** controls the delay following an Enter keystroke. Default: **250 ms**. Effective range: **50–3000 ms**.

**Before typing (ms)** gives you time to focus the target terminal after starting transmission. Default: **5000 ms** (5 seconds). Allowed range: **0–60000 ms**.

All delays are measured in **milliseconds (ms)**. Actual display timing can also depend on Windows scheduling, the browser, and the remote terminal.

## Keyboard shortcuts

**Ctrl+O** opens the file picker while TerminalTyper is focused. **Ctrl+Enter** starts typing from the application window. **F12** interrupts the current transmission.

## Troubleshooting

If nothing appears in the terminal, increase **Before typing (ms)** and make sure you click the terminal before the countdown ends.

If characters are missed or commands arrive too quickly, increase **Between keys (ms)** or **After Enter (ms)**. You can first test the program by typing a few harmless lines into Windows Notepad.

If a previous version seems to remain open, close the old AutoHotkey instance and start the updated script again.

## Security and privacy

TerminalTyper does not establish SSH connections or upload files by itself. It sends keystrokes to the active window. Double-check the destination before transmitting passwords, private keys, or any other sensitive data. Avoid typing secrets into a terminal where input may be echoed or logged.

## Repository files

`TerminalTyper.ahk` is the entire program. `README.md` is this documentation. `TerminalTyper_screenshot.png` is the image referenced above; keep it alongside this README so Markdown viewers can display it.
