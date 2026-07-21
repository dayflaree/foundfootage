# Third-party audio

## VHS UI sound pack

The files under `content/sound/vhs_ui/` are processed derivatives of Kenney's
**UI SFX Set / Interface Sounds**.

- Original author: Kenney Vleugels (Kenney.nl)
- Original asset page: <https://kenney.nl/assets/interface-sounds>
- Repackaged WAV source: <https://github.com/Calinou/kenney-ui-audio>
- Pinned source commit: `8c3d81b9159d058c444f89d12d518276b0b09345`
- License: Creative Commons Zero 1.0 Universal (CC0 1.0)
- License text: <https://creativecommons.org/publicdomain/zero/1.0/>
- Retrieved and processed: July 21, 2026

Kenney's source files are stereo, 16-bit PCM WAV at 44,100 Hz. The Found
Footage derivatives are mono, 16-bit PCM WAV at 44,100 Hz for Source/Garry's
Mod compatibility.

Processing applied deterministically with FFmpeg:

- mono downmix
- analog-style high-pass and low-pass filtering
- light amplitude flutter
- restrained bit-depth degradation blended with the clean signal
- seeded pink tape hiss
- mild tape-dropout envelopes on selected sounds
- output limiting with at least 1 dB of digital headroom

The exact source mapping, source hashes, output hashes, durations, and output
format are recorded in `tools/audio/vhs_ui_manifest.tsv`. The complete pack can
be rebuilt with `tools/audio/build_vhs_ui_sounds.py` using only Python 3, Git,
FFmpeg, and FFprobe.

### Included sounds

- `hover_01.wav`
- `hover_02.wav`
- `navigate_up.wav`
- `navigate_down.wav`
- `navigate_left.wav`
- `navigate_right.wav`
- `select_01.wav`
- `select_02.wav`
- `confirm_01.wav`
- `confirm_02.wav`
- `cancel_01.wav`
- `cancel_02.wav`
- `menu_open.wav`
- `menu_close.wav`
- `pause_open.wav`
- `pause_close.wav`
- `record_start.wav`
- `record_stop.wav`
- `tape_insert.wav`
- `tape_eject.wav`
- `warning.wav`
- `error.wav`
- `battery_low.wav`
- `signal_lost.wav`
