"""Unit tests for the adb camera grant that the live scenario depends on."""

from __future__ import annotations

import inspect
import subprocess
import threading
from typing import Any

import pytest

from text_sight_bench.config import BENCH_APP_ANDROID_ID
from text_sight_bench.subcommands import runner


@pytest.fixture(autouse=True)
def _no_poll_delay(monkeypatch: pytest.MonkeyPatch) -> None:
    """Polling cadence is timing, not logic — drop it so the loop runs at full speed."""
    monkeypatch.setattr(runner, "_GRANT_POLL_SECONDS", 0)
    monkeypatch.setattr(runner, "_REGRANT_POLL_SECONDS", 0)


class _FakeAdb:
    """Scripts one `pm list packages` answer per poll, stopping when the script runs out."""

    def __init__(self, presence: list[bool], stop: threading.Event) -> None:
        self._presence = presence
        self._stop = stop
        self.lists = 0
        self.grants = 0

    def __call__(self, cmd: list[str], **_: Any) -> subprocess.CompletedProcess[str]:
        if "grant" in cmd:
            self.grants += 1
            return subprocess.CompletedProcess(cmd, 0, "", "")

        index = self.lists
        self.lists += 1
        # The script running out stands in for `flutter drive` exiting.
        if index >= len(self._presence) - 1:
            self._stop.set()
        listed = f"package:{BENCH_APP_ANDROID_ID}\n" if self._presence[index] else ""
        return subprocess.CompletedProcess(cmd, 0, listed, "")


def _run_granter(
    presence: list[bool], monkeypatch: pytest.MonkeyPatch
) -> tuple[_FakeAdb, threading.Event]:
    stop = threading.Event()
    adb = _FakeAdb(presence, stop)
    monkeypatch.setattr(runner.subprocess, "run", adb)
    runner._grant_android_camera("emulator-5554", stop)
    return adb, stop


def test_grants_once_the_package_appears(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    adb, _ = _run_granter([False, False, True], monkeypatch)
    assert adb.grants == 1
    assert "granted android.permission.CAMERA" in capsys.readouterr().out


def test_polls_without_a_budget_of_its_own(monkeypatch: pytest.MonkeyPatch) -> None:
    """Nothing but `stop` ends the wait, however many polls the install takes."""
    adb, _ = _run_granter([False] * 5_000 + [True], monkeypatch)
    assert adb.lists == 5_001
    assert adb.grants == 1


def test_takes_no_deadline_parameter() -> None:
    """The drive's lifetime is the window. A clock here is what let a cold build outrun it.

    Pinned on the signature because the alternative is a test that has to burn the old
    90s deadline in real time to prove anything.
    """
    parameters = inspect.signature(runner._grant_android_camera).parameters
    assert list(parameters) == ["serial", "stop"]


def test_regrants_after_a_reinstall(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """`flutter drive` can reinstall, which drops the grant with the old package."""
    adb, _ = _run_granter([True, False, True], monkeypatch)
    assert adb.grants == 2
    # Only the first grant is worth a line; the rest are upkeep.
    assert capsys.readouterr().out.count("granted android.permission.CAMERA") == 1


def test_stops_as_soon_as_the_drive_exits(monkeypatch: pytest.MonkeyPatch) -> None:
    """The granter must not outlive the drive it was granting for."""
    adb, stop = _run_granter([True, True], monkeypatch)
    assert stop.is_set()
    assert adb.lists == 2


def test_missing_package_blames_the_build_not_a_timeout(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    adb, _ = _run_granter([False, False], monkeypatch)
    assert adb.grants == 0
    error = capsys.readouterr().err
    assert BENCH_APP_ANDROID_ID in error
    assert "emulator-5554" in error
    assert "flutter drive` exited" in error


def test_missing_adb_reports_instead_of_raising(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    def _no_adb(cmd: list[str], **_: Any) -> subprocess.CompletedProcess[str]:
        raise FileNotFoundError("adb")

    monkeypatch.setattr(runner.subprocess, "run", _no_adb)
    runner._grant_android_camera("emulator-5554", threading.Event())
    assert "no `adb` on PATH" in capsys.readouterr().err


def test_a_drive_that_dies_before_the_first_poll_still_reports(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """`stop` can already be set on entry when the drive fails instantly."""
    stop = threading.Event()
    stop.set()
    adb = _FakeAdb([True], stop)
    monkeypatch.setattr(runner.subprocess, "run", adb)
    runner._grant_android_camera("emulator-5554", stop)
    assert adb.lists == 0
    assert "could not grant CAMERA" in capsys.readouterr().err


def test_an_unreachable_device_is_not_blamed_on_the_build(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """`pm list` failing means adb lost the device, which is a different fix than a bad build."""
    stop = threading.Event()

    def _offline(cmd: list[str], **_: Any) -> subprocess.CompletedProcess[str]:
        stop.set()
        return subprocess.CompletedProcess(cmd, 1, "", "error: device offline\n")

    monkeypatch.setattr(runner.subprocess, "run", _offline)
    runner._grant_android_camera("emulator-5554", stop)
    error = capsys.readouterr().err
    assert "adb said: error: device offline" in error
    assert "the build or the install failed" not in error
