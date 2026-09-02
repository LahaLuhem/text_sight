"""`run` and `run-device` — execute the benchmarks, capturing result JSON files."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
from dataclasses import dataclass
from pathlib import Path

from text_sight_bench.config import (
    APP_DIR,
    BENCH_APP_ANDROID_ID,
    BENCHMARK_ROOT,
    CAMERA_SCENARIOS,
    DEFAULT_RESULTS_DIR,
    DEVICE_SCENARIOS,
    EXE_PATH,
    PACKAGE_PUBSPEC,
    PERF_DRIVER,
    RESULT_FILENAME,
)

# Tight while waiting on the install, slack afterwards: an adb round trip twice a second would
# land inside the measurement window and be counted as load.
_GRANT_POLL_SECONDS = 0.5
_REGRANT_POLL_SECONDS = 5.0
# A wedged `adb shell` must not outlive the run it was granting for.
_GRANT_STOP_SECONDS = 5.0


def cmd_run(args: argparse.Namespace) -> int:
    """Runs the exe with `--iterations`, writing `<out>/codec_roundtrip.json`."""
    if not EXE_PATH.exists():
        print(f"missing exe: {EXE_PATH}\n  run `python run.py build` first", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else DEFAULT_RESULTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / RESULT_FILENAME

    cmd = [
        str(EXE_PATH),
        "--iterations",
        str(args.iterations),
        "--output",
        str(out_file),
        "--git-sha",
        _git_sha(),
        "--package-version",
        _package_version(),
    ]
    print(f"running {args.iterations} iteration(s) -> {out_file}")
    result = subprocess.run(cmd, check=False)
    if result.returncode == 0:
        print(f"wrote: {out_file}")
    return result.returncode


def _git_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=BENCHMARK_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip() or "unknown"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def _package_version() -> str:
    """Reads `version:` from the package pubspec (no YAML dep for one line)."""
    try:
        for line in PACKAGE_PUBSPEC.read_text().splitlines():
            if line.startswith("version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "unknown"


@dataclass(frozen=True)
class Device:
    """One attachable target, as `flutter devices --machine` reports it."""

    id: str
    name: str
    platform: str
    virtual: bool

    @property
    def is_ios_simulator(self) -> bool:
        """No capture device on it, and it cannot run profile mode."""
        return self.virtual and self.platform == "ios"


def cmd_run_device(args: argparse.Namespace) -> int:
    """Drives a device scenario once per selected device, one JSON per platform."""
    scenario = args.scenario
    target = DEVICE_SCENARIOS.get(scenario)
    if target is None:
        known = ", ".join(sorted(DEVICE_SCENARIOS))
        print(f"unknown scenario {scenario!r}; known: {known}", file=sys.stderr)
        return 1

    devices = _select_devices(args)
    if not devices:
        where = "attached" if not args.include_virtual else "available"
        print(f"no {where} iOS or Android devices found", file=sys.stderr)
        print("  plug a phone in, or pass --include-virtual for a simulator", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else DEFAULT_RESULTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    failures = 0
    measured = 0

    for device in devices:
        if scenario in CAMERA_SCENARIOS and device.is_ios_simulator:
            # Cheaper to say so here than after an Xcode build and the scenario's permission wait.
            print(f"  skip  {scenario}  {device.name}: the iOS Simulator has no camera")
            continue

        out_file = out_dir / f"{scenario}_{device.platform}.json"
        # Simulators cannot run profile mode. Debug timings only prove the plumbing.
        mode = "--debug" if device.is_ios_simulator else "--profile"
        if mode == "--debug":
            print(f"  note: {device.name} is virtual, running {mode} (timings are not comparable)")

        print(f"\ndrive  {scenario}  {device.name}  ({args.iterations} iterations, {mode[2:]})")
        # No grant survives the uninstall, so grant from the side for as long as the drive runs.
        stop_granting = threading.Event()
        granter: threading.Thread | None = None
        if scenario in CAMERA_SCENARIOS and device.platform == "android":
            granter = threading.Thread(
                target=_grant_android_camera, args=(device.id, stop_granting), daemon=True
            )
            granter.start()

        result = subprocess.run(
            [
                "flutter",
                "drive",
                f"--driver={PERF_DRIVER}",
                f"--target={target}",
                mode,
                "-d",
                device.id,
                f"--dart-define=ITERATIONS={args.iterations}",
                f"--dart-define=OUTPUT={out_file}",
                f"--dart-define=GIT_SHA={_git_sha()}",
                f"--dart-define=PKG_VERSION={_package_version()}",
            ],
            cwd=APP_DIR,
            check=False,
        )
        stop_granting.set()
        if granter is not None:
            granter.join(timeout=_GRANT_STOP_SECONDS)

        if result.returncode != 0:
            print(f"  FAILED (exit {result.returncode})", file=sys.stderr)
            failures += 1
            continue
        print(f"  wrote: {out_file}")
        measured += 1

    if not failures and not measured:
        print(f"no selected device can run {scenario}", file=sys.stderr)

    return 1 if failures or not measured else 0


def _select_devices(args: argparse.Namespace) -> list[Device]:
    """Discovered devices, narrowed by `--device` / `--platform`."""
    devices = _discover_devices(include_virtual=args.include_virtual)
    if args.device:
        devices = [d for d in devices if d.id == args.device]
    if args.platform:
        devices = [d for d in devices if d.platform == args.platform]
    return devices


def _discover_devices(*, include_virtual: bool) -> list[Device]:
    """Parses `flutter devices --machine`, keeping iOS and Android targets."""
    try:
        out = subprocess.run(
            ["flutter", "devices", "--machine"], capture_output=True, text=True, check=True
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        print(f"could not list devices: {error}", file=sys.stderr)
        return []

    try:
        entries = json.loads(out.stdout)
    except json.JSONDecodeError:
        print("could not parse `flutter devices --machine` output", file=sys.stderr)
        return []

    devices: list[Device] = []
    for entry in entries:
        target = str(entry.get("targetPlatform", ""))
        platform = (
            "ios" if target.startswith("ios") else "android" if target.startswith("android") else ""
        )
        if not platform:
            continue
        virtual = bool(entry.get("emulator"))
        if virtual and not include_virtual:
            continue
        devices.append(
            Device(id=str(entry["id"]), name=str(entry["name"]), platform=platform, virtual=virtual)
        )
    return devices


def _grant_android_camera(serial: str, stop: threading.Event) -> None:
    """Grants CAMERA until `stop` is set, re-granting so a reinstall cannot drop it.

    `flutter drive` installs at run start and removes the app at the end, so that window is the
    only time the grant can exist. `stop` is what bounds this loop, not a clock: a cold Gradle
    build outlasts any deadline worth hardcoding.
    """
    granted = False
    problem = ""
    while not stop.is_set():
        try:
            listed = subprocess.run(
                ["adb", "-s", serial, "shell", "pm", "list", "packages", BENCH_APP_ANDROID_ID],
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            print("  could not grant CAMERA: no `adb` on PATH", file=sys.stderr, flush=True)
            return

        problem = listed.stderr.strip()
        if BENCH_APP_ANDROID_ID in listed.stdout:
            subprocess.run(
                [
                    "adb",
                    "-s",
                    serial,
                    "shell",
                    "pm",
                    "grant",
                    BENCH_APP_ANDROID_ID,
                    "android.permission.CAMERA",
                ],
                capture_output=True,
                check=False,
            )
            if not granted:
                print("  granted android.permission.CAMERA over adb", flush=True)
                granted = True
        stop.wait(_REGRANT_POLL_SECONDS if granted else _GRANT_POLL_SECONDS)

    if not granted:
        # The drive has already exited here, so "still building" is not on the table.
        blame = f"adb said: {problem}" if problem else "the build or the install failed"
        print(
            f"  could not grant CAMERA: {BENCH_APP_ANDROID_ID} never appeared on {serial} before"
            f" `flutter drive` exited, so {blame}",
            file=sys.stderr,
            flush=True,
        )
