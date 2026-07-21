#!/usr/bin/env python3
"""Build the Found Footage VHS UI sound pack from pinned CC0 sources.

Requirements: git, ffmpeg, ffprobe, Python 3 standard library.
Outputs are mono, 16-bit PCM WAV at 44.1 kHz for Source/Garry's Mod.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import tempfile

REPOSITORY = "https://github.com/Calinou/kenney-ui-audio.git"
COMMIT = "8c3d81b9159d058c444f89d12d518276b0b09345"
SOURCE_SUBDIR = Path("addons/kenney_ui_audio")
SAMPLE_RATE = 44_100

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "content/sound/vhs_ui"
MANIFEST_PATH = PROJECT_ROOT / "tools/audio/vhs_ui_manifest.tsv"


@dataclass(frozen=True)
class SoundSpec:
    output: str
    source: str
    source_sha256: str
    ratio: float
    highpass: int
    lowpass: int
    bits: float
    crush_mix: float
    hiss: float
    flutter_hz: float
    flutter_depth: float
    gain: float
    dropout: float | None = None
    dropout_width: float = 0.010
    dropout_gain: float = 0.45


SOUNDS = (
    SoundSpec("hover_01.wav", "rollover2.wav", "c0c10c006967920edbb29ca364099a42ad3459a823d75f18a90181ac36774bf2", 1.04, 240, 7600, 13.5, 0.08, 0.0028, 6.1, 0.025, 1.18),
    SoundSpec("hover_02.wav", "rollover3.wav", "f3a9e0cf97fd20c963d3793a42fc26a8f137b11d916cce1aca10b6419521eaa3", 0.98, 220, 7200, 13.0, 0.10, 0.0030, 5.7, 0.030, 1.16),
    SoundSpec("navigate_up.wav", "switch12.wav", "266a9ea6596cfee50e2970ca047b4485802678aecf7a25e6b60feff9c4c523ee", 1.07, 260, 7600, 13.0, 0.10, 0.0031, 6.8, 0.025, 1.18),
    SoundSpec("navigate_down.wav", "switch13.wav", "89f5746144f41a5dbf889d017ab549a6246922662321ddf25a76b4de69f7819c", 0.94, 230, 7000, 12.5, 0.12, 0.0033, 5.4, 0.035, 1.18),
    SoundSpec("navigate_left.wav", "switch14.wav", "d724a9922ce3d978069b02401f6aafdb3fd247a1a55d54a7e3e3e062e400f44c", 0.97, 250, 6800, 12.5, 0.12, 0.0032, 6.0, 0.030, 1.20),
    SoundSpec("navigate_right.wav", "click4.wav", "0d80e2c82426316b140b0686e10f83924ef794e9a9dfe13aaaa794b18200b048", 1.05, 250, 7400, 13.0, 0.10, 0.0030, 6.5, 0.025, 1.20),
    SoundSpec("select_01.wav", "click1.wav", "dd90b97f38b0ec7d52161d7c3bf8d61a66655766fd0af06439963351b4853a83", 0.99, 180, 7200, 12.0, 0.14, 0.0035, 5.8, 0.035, 1.15, 0.58),
    SoundSpec("select_02.wav", "click3.wav", "8d0676a5bcbfedad3e65b7b73e93a044216d7f192c99a3a05caf21e2aa4a8dda", 1.03, 190, 7500, 12.5, 0.12, 0.0034, 6.3, 0.030, 1.17, 0.64),
    SoundSpec("confirm_01.wav", "switch15.wav", "f5a1a4e3e5af752cb937475dd88a0db8c7a53219c11162bc2a6800b0e54997e9", 1.02, 170, 7000, 13.0, 0.10, 0.0033, 5.9, 0.030, 1.12, 0.72),
    SoundSpec("confirm_02.wav", "switch16.wav", "f8c17ff7909677d8fe52617828dc057f62fd024603e6272c6f54baa968f5aa84", 1.05, 160, 7200, 13.5, 0.08, 0.0032, 6.2, 0.025, 1.10, 0.76),
    SoundSpec("cancel_01.wav", "switch20.wav", "ec0651a79a3c3ff90d419ad2d1f05fb0eb7c901ce867a10e12070d93c2823122", 0.94, 200, 6200, 11.5, 0.17, 0.0040, 5.2, 0.045, 1.12, 0.44, 0.014, 0.32),
    SoundSpec("cancel_02.wav", "switch21.wav", "dbfb199e1ef3133be680dff6b6e4a5369fcd06cefd9c23bcc0305c52c4dfe08b", 0.91, 210, 5900, 11.0, 0.18, 0.0042, 4.9, 0.050, 1.12, 0.51, 0.016, 0.28),
    SoundSpec("menu_open.wav", "switch1.wav", "e48f397e7dffafab68a2252287b8ff0e3805f141f76e51a3c6285e72e0d443d0", 1.02, 150, 6900, 13.0, 0.10, 0.0036, 5.8, 0.035, 1.10, 0.66),
    SoundSpec("menu_close.wav", "switch2.wav", "b0f7b256b9baa6ff7558c2d7404d29754671939627b9ae27cc49b5d558721170", 0.96, 170, 6500, 12.5, 0.12, 0.0038, 5.4, 0.040, 1.10, 0.60),
    SoundSpec("pause_open.wav", "switch3.wav", "2c04718535a175affda107adc8cad34abdccc94b9a9100297e39a0077c207515", 0.99, 140, 6600, 12.5, 0.13, 0.0040, 5.6, 0.040, 1.08, 0.35, 0.018, 0.38),
    SoundSpec("pause_close.wav", "switch4.wav", "83956adf4ac68a44a7ab6d7f69d03560a3e575fa1cc11431fe291f859f2178a9", 0.95, 160, 6200, 12.0, 0.14, 0.0041, 5.1, 0.045, 1.08, 0.42, 0.018, 0.34),
    SoundSpec("record_start.wav", "switch25.wav", "30eb9d63183ebca277f2814e0e50ca72ba0b1b847a8572ead63e1e718afd2c3f", 1.01, 120, 6500, 11.5, 0.16, 0.0043, 5.5, 0.045, 1.10, 0.56, 0.012, 0.40),
    SoundSpec("record_stop.wav", "switch26.wav", "321e5ac1799711e15acecff6a44eb20a2428af5544c41e5638bd659e28af47b5", 0.93, 140, 6000, 11.0, 0.18, 0.0045, 5.0, 0.050, 1.12, 0.47, 0.015, 0.30),
    SoundSpec("tape_insert.wav", "switch30.wav", "7cb1cf16f8fe8da66d5386dbbd1cf9eb9442abacb8c837949580c0ff67382bf6", 0.92, 100, 5600, 10.5, 0.20, 0.0050, 4.8, 0.055, 1.10, 0.62, 0.020, 0.24),
    SoundSpec("tape_eject.wav", "switch31.wav", "788f8f47754ff274f6c2c9b0235bb02a106258d250a49aeec391f1d1b9eeb25c", 0.90, 110, 5400, 10.0, 0.22, 0.0052, 4.5, 0.060, 1.10, 0.54, 0.022, 0.22),
    SoundSpec("warning.wav", "switch34.wav", "9406e17254c90136b615bc010bdece30aebda5c4c6b2aa87f8055776ae5d995d", 0.95, 190, 6100, 11.0, 0.20, 0.0050, 5.0, 0.055, 1.14, 0.38, 0.020, 0.25),
    SoundSpec("error.wav", "switch35.wav", "80b79cf3dc8631621e6f2445aef9fddfc9229f323c9a6b3fae4b60fe4abb5985", 0.88, 220, 5200, 9.5, 0.25, 0.0060, 4.2, 0.070, 1.16, 0.46, 0.024, 0.18),
    SoundSpec("battery_low.wav", "switch36.wav", "a0a20d1447aa375a3c371aec3ef3cec7326690317b118d2e842f4eec39d535f9", 0.92, 180, 5800, 10.5, 0.22, 0.0055, 4.7, 0.060, 1.15, 0.63, 0.018, 0.25),
    SoundSpec("signal_lost.wav", "switch38.wav", "a1d46a899fb7ec4f31bb58d0c19491112bc8e5144e0c79e02dd5353a1af8fedc", 0.86, 260, 4700, 8.5, 0.30, 0.0075, 3.8, 0.085, 1.18, 0.52, 0.035, 0.12),
)


def run(command: list[str], *, cwd: Path | None = None) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def file_sha256(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_duration(path: Path) -> float:
    value = run([
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(path),
    ])
    return float(value)


def build_filter(spec: SoundSpec, duration: float, seed: int) -> str:
    processed_duration = max(0.08, min(0.75, duration / spec.ratio + 0.045))
    fade_out_start = max(0.0, processed_duration - 0.030)
    asetrate = int(round(SAMPLE_RATE * spec.ratio))

    base = (
        f"[0:a]pan=mono|c0=0.5*c0+0.5*c1,"
        f"aresample={SAMPLE_RATE},asetrate={asetrate},aresample={SAMPLE_RATE},"
        f"highpass=f={spec.highpass},lowpass=f={spec.lowpass},"
        f"tremolo=f={spec.flutter_hz}:d={spec.flutter_depth},"
        f"acrusher=bits={spec.bits}:mix={spec.crush_mix}:aa=0.85:samples=1,"
        f"volume={spec.gain},apad=pad_dur=0.05,atrim=duration={processed_duration:.6f},"
        f"afade=t=in:st=0:d=0.003,"
        f"afade=t=out:st={fade_out_start:.6f}:d=0.030[base]"
    )
    hiss = (
        f"anoisesrc=r={SAMPLE_RATE}:a={spec.hiss}:d={processed_duration:.6f}:"
        f"c=pink:s={seed},highpass=f=1200,lowpass=f=9000,"
        f"tremolo=f=0.8:d=0.18,afade=t=in:st=0:d=0.004,"
        f"afade=t=out:st={fade_out_start:.6f}:d=0.030[hiss]"
    )
    mixed = "[base][hiss]amix=inputs=2:duration=longest:normalize=0"

    if spec.dropout is not None:
        dropout_start = max(0.006, processed_duration * spec.dropout)
        dropout_end = min(processed_duration - 0.006, dropout_start + spec.dropout_width)
        mixed += (
            f",volume=volume={spec.dropout_gain}:"
            f"enable='between(t,{dropout_start:.6f},{dropout_end:.6f})'"
        )

    mixed += ",alimiter=limit=0.88:level=false[out]"
    return ";".join((base, hiss, mixed))


def main() -> None:
    for executable in ("git", "ffmpeg", "ffprobe"):
        if shutil.which(executable) is None:
            raise SystemExit(f"Missing required executable: {executable}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for old_file in OUTPUT_DIR.glob("*.wav"):
        old_file.unlink()

    manifest_rows = [
        "output\tsource\tsource_sha256\toutput_sha256\tsample_rate\tchannels\tcodec\tduration_seconds"
    ]

    with tempfile.TemporaryDirectory(prefix="ff-vhs-ui-") as temporary:
        checkout = Path(temporary) / "kenney-ui-audio"
        run(["git", "clone", "--quiet", REPOSITORY, str(checkout)])
        run(["git", "checkout", "--quiet", COMMIT], cwd=checkout)

        resolved_commit = run(["git", "rev-parse", "HEAD"], cwd=checkout)
        if resolved_commit != COMMIT:
            raise SystemExit(f"Unexpected source commit: {resolved_commit}")

        source_dir = checkout / SOURCE_SUBDIR
        for index, spec in enumerate(SOUNDS, start=1):
            source = source_dir / spec.source
            if not source.is_file():
                raise SystemExit(f"Missing source file: {source}")

            actual_source_hash = file_sha256(source)
            if actual_source_hash != spec.source_sha256:
                raise SystemExit(
                    f"Source hash mismatch for {spec.source}: "
                    f"{actual_source_hash} != {spec.source_sha256}"
                )

            original_duration = source_duration(source)
            filter_graph = build_filter(spec, original_duration, 19790101 + index * 101)
            output = OUTPUT_DIR / spec.output

            run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-i", str(source),
                "-filter_complex", filter_graph,
                "-map", "[out]",
                "-ar", str(SAMPLE_RATE),
                "-ac", "1",
                "-c:a", "pcm_s16le",
                "-map_metadata", "-1",
                str(output),
            ])

            probe = run([
                "ffprobe", "-v", "error",
                "-select_streams", "a:0",
                "-show_entries", "stream=sample_rate,channels,codec_name:format=duration",
                "-of", "default=noprint_wrappers=1",
                str(output),
            ])
            fields = dict(line.split("=", 1) for line in probe.splitlines() if "=" in line)
            if fields.get("sample_rate") != str(SAMPLE_RATE):
                raise SystemExit(f"Bad sample rate for {output}: {fields}")
            if fields.get("channels") != "1":
                raise SystemExit(f"Bad channel count for {output}: {fields}")
            if fields.get("codec_name") != "pcm_s16le":
                raise SystemExit(f"Bad codec for {output}: {fields}")

            manifest_rows.append(
                "\t".join((
                    spec.output,
                    spec.source,
                    spec.source_sha256,
                    file_sha256(output),
                    fields["sample_rate"],
                    fields["channels"],
                    fields["codec_name"],
                    f"{float(fields['duration']):.6f}",
                ))
            )
            print(f"built {spec.output}")

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text("\n".join(manifest_rows) + "\n", encoding="utf-8")
    print(f"wrote {MANIFEST_PATH.relative_to(PROJECT_ROOT)}")
    print(f"built {len(SOUNDS)} files in {OUTPUT_DIR.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
