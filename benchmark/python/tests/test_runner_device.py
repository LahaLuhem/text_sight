"""Unit tests for `run-device` device selection and per-device skipping."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path
from typing import Any

import pytest

from text_sight_bench.subcommands import runner
from text_sight_bench.subcommands.runner import Device

_IOS_SIM = Device(id="7E77-SIM", name="iPhone 17 Pro Max", platform="ios", virtual=True)
_ANDROID_EMU = Device(id="emulator-5554", name="sdk gphone arm64", platform="android", virtual=True)
_IPHONE = Device(id="00008130-PHONE", name="iPhone", platform="ios", virtual=False)


class _FakeRun:
    """Stands in for every `subprocess.run` the runner makes, recording the commands."""

    def __init__(self) -> None:
        self.commands: list[list[str]] = []

    def __call__(self, cmd: list[str], **_: Any) -> subprocess.CompletedProcess[str]:
        self.commands.append(list(cmd))
        if cmd[0] == "git":
            return subprocess.CompletedProcess(cmd, 0, "abc1234\n", "")
        return subprocess.CompletedProcess(cmd, 0, "", "")

    @property
    def drives(self) -> list[list[str]]:
        return [cmd for cmd in self.commands if cmd[0] == "flutter"]


@pytest.fixture
def fake_run(monkeypatch: pytest.MonkeyPatch) -> _FakeRun:
    fake = _FakeRun()
    monkeypatch.setattr(runner.subprocess, "run", fake)
    # The grant needs a real device on the other end, and its own tests cover it.
    monkeypatch.setattr(runner, "_grant_android_camera", lambda *_: None)
    return fake


def _args(scenario: str, out: Path) -> argparse.Namespace:
    return argparse.Namespace(
        scenario=scenario,
        iterations=1,
        device=None,
        platform=None,
        include_virtual=True,
        out=str(out),
    )


def _with_devices(monkeypatch: pytest.MonkeyPatch, *devices: Device) -> None:
    monkeypatch.setattr(runner, "_discover_devices", lambda **_: list(devices))


def test_skips_a_camera_scenario_on_an_ios_simulator(
    monkeypatch: pytest.MonkeyPatch,
    fake_run: _FakeRun,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """The simulator has no capture device, so building for it only wastes an Xcode build."""
    _with_devices(monkeypatch, _IOS_SIM)
    code = runner.cmd_run_device(_args("live_throughput", tmp_path))

    assert fake_run.drives == [], "skipping must happen before the build"
    assert "the iOS Simulator has no camera" in capsys.readouterr().out
    assert code == 1


def test_a_run_that_measured_nothing_does_not_report_success(
    monkeypatch: pytest.MonkeyPatch,
    fake_run: _FakeRun,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Every device skipped is not a pass, or CI reads it as numbers captured."""
    _with_devices(monkeypatch, _IOS_SIM)
    code = runner.cmd_run_device(_args("live_throughput", tmp_path))

    assert code == 1
    assert "no selected device can run live_throughput" in capsys.readouterr().err


def test_a_skipped_simulator_does_not_fail_a_run_that_measured(
    monkeypatch: pytest.MonkeyPatch, fake_run: _FakeRun, tmp_path: Path
) -> None:
    """A skip is not a failure: the Android leg still carries the run."""
    _with_devices(monkeypatch, _ANDROID_EMU, _IOS_SIM)
    code = runner.cmd_run_device(_args("live_throughput", tmp_path))

    assert len(fake_run.drives) == 1
    assert "-d" in fake_run.drives[0]
    assert _ANDROID_EMU.id in fake_run.drives[0]
    assert code == 0


def test_a_physical_iphone_still_runs_the_camera_scenario(
    monkeypatch: pytest.MonkeyPatch, fake_run: _FakeRun, tmp_path: Path
) -> None:
    """The skip is about the simulator, not about iOS."""
    _with_devices(monkeypatch, _IPHONE)
    code = runner.cmd_run_device(_args("live_throughput", tmp_path))

    assert len(fake_run.drives) == 1
    assert "--profile" in fake_run.drives[0]
    assert code == 0


def test_a_cameraless_scenario_still_runs_on_a_simulator(
    monkeypatch: pytest.MonkeyPatch, fake_run: _FakeRun, tmp_path: Path
) -> None:
    """`one_shot_latency` renders its own pages, so the simulator is a valid target."""
    _with_devices(monkeypatch, _IOS_SIM)
    code = runner.cmd_run_device(_args("one_shot_latency", tmp_path))

    assert len(fake_run.drives) == 1
    assert "--debug" in fake_run.drives[0]
    assert code == 0
