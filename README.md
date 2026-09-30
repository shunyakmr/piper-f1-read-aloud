# piper-f1-read-aloud

Highlight text anywhere on Windows, press **F1**, and hear it read aloud by a natural-sounding
offline voice. Press **F2** to stop.

It glues together two free tools:

- [Piper](https://github.com/OHF-Voice/piper1-gpl) — a fast, local neural text-to-speech engine
  (no internet or account needed once installed)
- [AutoHotkey v2](https://www.autohotkey.com/) — lets a key like F1 run a command

The default voice is [`en_GB-cori-high`](https://rhasspy.github.io/piper-samples/#en_GB-cori-high)
(British English). Any voice from the [samples page](https://rhasspy.github.io/piper-samples/) works.

## Quick install

1. Download this repo (**Code → Download ZIP**, then unzip, or `git clone`).
2. Open **PowerShell** in the unzipped folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. Highlight some text in any app and press **F1**.

The installer is safe to run again; it skips anything already done.

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `-Voice <name>` | `en_GB-cori-high` | Any voice name from the samples page, e.g. `en_GB-alba-medium` |
| `-InstallDir <path>` | `$HOME\piper` | Where Piper, the voice and recordings live |
| `-NoStartup` | off | Don't start the hotkey automatically with Windows |

## Manual install

If you'd rather do each step yourself (PowerShell):

```powershell
# 1. Python 3.9+ (skip if `python --version` already works; open a new window afterwards)
winget install Python.Python.3.12

# 2. Folder + virtual environment
mkdir $HOME\piper; cd $HOME\piper
python -m venv .venv
.\.venv\Scripts\Activate.ps1      # if blocked: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 3. Piper and a voice (~114 MB for cori-high)
pip install piper-tts
python -m piper.download_voices en_GB-cori-high

# 4. Test
python -m piper -m en_GB-cori-high -f test.wav -- "Hello, this is a test."
start test.wav

# 5. AutoHotkey v2
winget install AutoHotkey.AutoHotkey
```

Then copy `speak.ahk` and `speak.py` from this repo into `$HOME\piper` and double-click `speak.ahk`. A green **H** icon
appears in the system tray.

To start it with Windows: press `Win+R`, type `shell:startup`, and put a shortcut to `speak.ahk` there.

## How it works

```
 you highlight text, press F1
            │
            ▼
 speak.ahk (AutoHotkey)
   1. saves your clipboard, sends Ctrl+C, reads the selection, restores the clipboard
   2. stops any reading still in progress
   3. shows a pop-up by the mouse: "F1 fired — loading voice…"
   4. deletes recordings older than KeepHours from the audio folder
   5. writes the text to %TEMP%\piper_in.txt
   6. starts speak.py (hidden window):
        .venv\Scripts\python.exe speak.py <voice>.onnx piper_in.txt audio\<date>_<time>.wav
            │
            ▼
 speak.py (Python)
   - loads the voice once, then Piper generates the text one sentence at a time
   - each sentence plays as soon as it's ready, while the next is generated
     (so long selections start speaking in a few seconds, not after the whole text)
   - the full reading is also saved to the WAV file
            │
            ▼
 pop-up changes to "🔊 Reading aloud — F2 to stop", and disappears when finished
 F1 again → cancels the current reading and reads the new selection
 F2       → stops reading
```

Files after installing:

```
%USERPROFILE%\piper\
├── .venv\                     Python environment with piper-tts
├── en_GB-cori-high.onnx       the voice model
├── en_GB-cori-high.onnx.json  voice settings
├── speak.ahk                  the hotkey script
├── speak.py                   plays Piper's audio sentence by sentence
├── test.wav                   from the install test
└── audio\                     recordings, one per F1 press, e.g. 2026-09-30_22-51-07.wav
```

### Why every press gets a new file

Each reading is saved with its own timestamped name, so you can replay recent ones from the
`audio` folder. Recordings older than `KeepHours` are cleaned up automatically the next time you
press F1. (An early version reused one file name; Windows kept it locked after playing, so the
**previous** recording played again.)

## Customising

Edit the top of `speak.ahk`, then right-click the tray **H** icon → **Reload Script**:

| Setting | What it does |
| --- | --- |
| `Voice := "en_GB-cori-high"` | Voice to use (download it first with `python -m piper.download_voices <name>`) |
| `KeepHours := 24` | How long recordings stay in the `audio` folder |
| `F1::` / `F2::` | The keys. E.g. `^!s::` = Ctrl+Alt+S, `#s::` = Win+S |

Speed, pauses and volume can be set in `speak.py` by passing a `SynthesisConfig` to
`voice.synthesize(text, ...)`, e.g. `SynthesisConfig(length_scale=0.9, volume=1.2)`
(`from piper import SynthesisConfig`; lower `length_scale` = faster).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Nothing happens on F1 | Is the green **H** tray icon there? If not, double-click `speak.ahk`. Make sure text is actually highlighted. |
| Still silent | Run the test in step 4 of the manual install from `$HOME\piper` to see Piper's error message. |
| Same passage repeats | You have an old `speak.ahk` that reuses one WAV file; copy the current one from this repo. |
| `python` opens the Microsoft Store | Python isn't on PATH. Reinstall with "Add python.exe to PATH" ticked, or use `py`. |
| Pop-up says "loading" for a few seconds | Normal: the voice loads on every press, then the first sentence is generated. `-medium` / `-low` voices are faster. |
| Long text takes a minute to start | You have an old `speak.ahk` that generates everything first; copy the current `speak.ahk` and `speak.py`. |
| F1 no longer opens Help in apps | Expected while the script runs; change the key if you need F1. |

## Uninstall

1. Right-click the tray **H** icon → **Exit**.
2. Delete `speak.lnk` from the `shell:startup` folder.
3. Delete the `%USERPROFILE%\piper` folder.
4. Optionally: `winget uninstall AutoHotkey.AutoHotkey`.

## Licences

The scripts in this repo are MIT licensed (see [LICENSE](LICENSE)). Piper is GPL-3.0 and is
installed separately from PyPI. Each voice has its own licence; see its `MODEL_CARD` on
[Hugging Face (rhasspy/piper-voices)](https://huggingface.co/rhasspy/piper-voices).
