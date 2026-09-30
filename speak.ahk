#Requires AutoHotkey v2.0
#SingleInstance Force

PiperDir := EnvGet("USERPROFILE") "\piper"
Voice    := "en_GB-cori-high"
TxtFile  := A_Temp "\piper_in.txt"
AudioDir := PiperDir "\audio"     ; recordings are kept here
KeepHours := 24                   ; delete recordings older than this
DirCreate AudioDir
ReaderPid := 0                    ; the reading in progress, if any
WavFile := ""

F1:: {
    global ReaderPid, WavFile
    ; copy the current selection, keeping the old clipboard
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5) {
        A_Clipboard := saved
        Notify("F1: no text selected", 2000)
        return
    }
    text := A_Clipboard
    A_Clipboard := saved

    StopReading()                      ; stop anything already playing
    Notify("F1 fired — loading voice…")
    ; delete recordings older than KeepHours
    Loop Files AudioDir "\*.wav"
        if DateDiff(A_Now, A_LoopFileTimeModified, "Hours") >= KeepHours
            try FileDelete A_LoopFileFullPath
    WavFile := AudioDir "\" FormatTime(, "yyyy-MM-dd_HH-mm-ss") ".wav"
    try FileDelete TxtFile
    FileAppend text, TxtFile, "UTF-8-RAW"

    ; speak.py plays each sentence as soon as it is ready
    cmd := '"' PiperDir '\.venv\Scripts\python.exe" "' PiperDir '\speak.py" "'
         . PiperDir '\' Voice '.onnx" "' TxtFile '" "' WavFile '"'
    Run cmd, PiperDir, "Hide", &ReaderPid
    SetTimer WatchReading, 200
}

; update the pop-up: loading → reading → gone when finished
WatchReading() {
    if !ReaderPid || !ProcessExist(ReaderPid) {
        SetTimer WatchReading, 0
        ToolTip
        return
    }
    ; the recording grows past its 44-byte header once speech has started
    if FileExist(WavFile) && FileGetSize(WavFile) > 44
        ToolTip "🔊 Reading aloud — F2 to stop"
}

; show a pop-up near the mouse; hide it after ms (0 = keep until replaced)
Notify(msg, ms := 0) {
    ToolTip msg
    if ms
        SetTimer () => ToolTip(), -ms
}

StopReading() {
    global ReaderPid
    SetTimer WatchReading, 0
    ToolTip
    if ReaderPid
        try ProcessClose ReaderPid
    ReaderPid := 0
}

F2:: StopReading()                  ; stop reading
