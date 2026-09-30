# Reads a text file aloud with Piper, sentence by sentence, so speech starts
# almost immediately instead of after the whole text has been generated.
# Usage: python speak.py <voice.onnx> <input.txt> <output.wav>

import io
import queue
import sys
import threading
import wave
import winsound

from piper import PiperVoice

model, txt_file, wav_file = sys.argv[1:4]
voice = PiperVoice.load(model)
text = open(txt_file, encoding="utf-8").read()

chunks = queue.Queue()


def generate():
    # also save the full reading, so it can be replayed later
    with wave.open(wav_file, "wb") as full:
        for i, chunk in enumerate(voice.synthesize(text)):
            if i == 0:
                full.setframerate(chunk.sample_rate)
                full.setsampwidth(chunk.sample_width)
                full.setnchannels(chunk.sample_channels)
            full.writeframes(chunk.audio_int16_bytes)
            chunks.put(chunk)
    chunks.put(None)


threading.Thread(target=generate, daemon=True).start()

# play each sentence while the next one is being generated
while (chunk := chunks.get()) is not None:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setframerate(chunk.sample_rate)
        w.setsampwidth(chunk.sample_width)
        w.setnchannels(chunk.sample_channels)
        w.writeframes(chunk.audio_int16_bytes)
    winsound.PlaySound(buf.getvalue(), winsound.SND_MEMORY)
