#Requires AutoHotkey v2.0
#SingleInstance Force

PiperDir := EnvGet("USERPROFILE") "\piper"
Voice    := "en_GB-cori-high"
TxtFile  := A_Temp "\piper_in.txt"
AudioDir := PiperDir "\audio"     ; recordings are kept here
KeepHours := 24                   ; delete recordings older than this
DirCreate AudioDir

F1:: {
    ; copy the current selection, keeping the old clipboard
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5) {
        A_Clipboard := saved
        return
    }
    text := A_Clipboard
    A_Clipboard := saved

    SoundPlay "*nonexistent*"          ; stop anything already playing
    ; delete recordings older than KeepHours
    Loop Files AudioDir "\*.wav"
        if DateDiff(A_Now, A_LoopFileTimeModified, "Hours") >= KeepHours
            try FileDelete A_LoopFileFullPath
    ; Windows keeps the last WAV locked, so use a new file each time
    WavFile := AudioDir "\" FormatTime(, "yyyy-MM-dd_HH-mm-ss") ".wav"
    try FileDelete TxtFile
    FileAppend text, TxtFile, "UTF-8-RAW"

    cmd := '"' PiperDir '\.venv\Scripts\python.exe" -m piper -m ' Voice
         . ' --data-dir "' PiperDir '" -f "' WavFile '" --input-file "' TxtFile '"'
    RunWait cmd, PiperDir, "Hide"
    SoundPlay WavFile
}

F2:: SoundPlay "*nonexistent*"      ; stop reading