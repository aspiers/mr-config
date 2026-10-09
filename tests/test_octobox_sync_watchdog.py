#!/usr/bin/env python3
"""No test command is allowed to reach the real worker or Redis."""

import importlib.machinery
import importlib.util
import json
import pathlib
import socket
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts/octobox-sync-watchdog"
loader = importlib.machinery.SourceFileLoader("watchdog", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
watchdog = importlib.util.module_from_spec(spec)
loader.exec_module(watchdog)


class FakeCommands:
    def __init__(self):
        self.calls = []
        self.pid = 1234
        self.invocation = "first"
        self.started = 1_000_000_000
        self.info = {"pid": self.pid, "hostname": socket.gethostname(), "started_at": 2000}
        self.identity = "test-worker"
        self.beat = 2000
        self.work = {"thread": json.dumps({
            "run_at": 2399,
            "payload": {"class": "SyncNotificationsWorker", "jid": "fake-job", "args": []},
        })}
        self.active = True
        self.fail_redis = False
        self.fail_restart = False
        self.change_on_recheck = False
        self.change_during_confirmation = False
        self.stop_during_confirmation = False
        self.finish_on_recheck = False
        self.same_after_restart = False
        self.state_checks = 0
        self.work_checks = 0

    def __call__(self, argv, timeout=5):
        self.calls.append(argv)
        if argv[:3] == ["systemctl", "--user", "show"]:
            self.state_checks += 1
            if self.change_on_recheck and self.state_checks == 2:
                self.pid += 1
                self.invocation = "other"
            return (f"ActiveState={'active' if self.active else 'inactive'}\n"
                    f"SubState={'running' if self.active else 'dead'}\n"
                    f"MainPID={self.pid}\nInvocationID={self.invocation}\n"
                    f"ExecMainStartTimestampMonotonic={self.started}\n")
        if argv[:3] == ["systemctl", "--user", "try-restart"]:
            if self.fail_restart:
                raise watchdog.InspectionError("restart failed")
            if not self.same_after_restart:
                self.pid += 1
                self.invocation = "restarted"
            return ""
        if argv[0] != "redis-cli":
            raise AssertionError(f"unexpected command: {argv}")
        if self.fail_redis:
            raise watchdog.InspectionError("Redis unavailable")
        operation = argv[4:]
        if operation == ["SMEMBERS", "processes"]:
            return json.dumps([self.identity])
        if operation == ["HGET", self.identity, "info"]:
            return json.dumps(json.dumps(self.info))
        if operation == ["HGET", self.identity, "beat"]:
            return json.dumps(str(self.beat))
        if operation == ["HGETALL", self.identity + ":work"]:
            self.work_checks += 1
            if self.work_checks == 2:
                if self.change_during_confirmation:
                    self.pid += 1
                    self.invocation = "other"
                if self.stop_during_confirmation:
                    self.active = False
            return json.dumps({} if self.finish_on_recheck and self.work_checks > 1 else self.work)
        raise AssertionError(f"unexpected Redis command: {operation}")

    @property
    def restarts(self):
        return [argv for argv in self.calls if argv[:3] == ["systemctl", "--user", "try-restart"]]


class WatchdogTest(unittest.TestCase):
    def setUp(self):
        self.commands = FakeCommands()
        self.messages = []
        self.clock = 2000
        key = json.dumps([self.commands.identity, "thread", "fake-job", 2399])
        self.observations = {
            "service": {"pid": 1234, "started": 1000, "invocation": "first"},
            "jobs": {key: {"first_seen": 1399, "beat": 1900, "over_budget": True}},
        }

    def run_watchdog(self, redis_url="redis://127.0.0.1:6380"):
        return watchdog.run_watchdog(
            self.observations, command=self.commands, monotonic=lambda: self.clock,
            emit=self.messages.append, redis_url=redis_url,
        )

    def change_work(self, **changes):
        work = json.loads(self.commands.work["thread"])
        work.update(changes)
        self.commands.work["thread"] = json.dumps(work)

    def test_confirmed_stale_sync_restarts_only_the_worker(self):
        self.run_watchdog()
        self.assertEqual([["systemctl", "--user", "try-restart", "octobox-sidekiq.service"]], self.commands.restarts)
        self.assertIn("601", " ".join(self.messages))
        self.assertIn("restarted", self.messages[-1])
        self.assertEqual({}, self.observations)

    def test_exactly_ten_minutes_is_not_over_budget(self):
        next(iter(self.observations["jobs"].values()))["first_seen"] = 1400
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_new_observation_requires_ten_minutes_and_a_later_confirmation(self):
        self.observations.clear()
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)
        self.clock += 601
        self.commands.beat += 601
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)
        self.clock += 60
        self.commands.beat += 60
        self.run_watchdog()
        self.assertEqual(1, len(self.commands.restarts))

    def test_new_execution_of_same_job_resets_the_budget(self):
        self.change_work(run_at=2900)
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_other_job_classes_are_not_restarted(self):
        self.change_work(payload={"class": "SyncStatusWorker", "jid": "other-job"})
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_inactive_service_is_not_started(self):
        self.commands.active = False
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)
        self.assertFalse(any(argv[0] == "redis-cli" for argv in self.commands.calls))
        self.assertEqual({}, self.observations)

    def test_another_pid_or_host_is_not_restarted(self):
        for field, value in [("pid", 999), ("hostname", "another-test-host")]:
            with self.subTest(field=field):
                self.commands.info[field] = value
                self.run_watchdog()
                self.assertFalse(self.commands.restarts)
                self.commands.info = {"pid": 1234, "hostname": socket.gethostname(), "started_at": 2000}

    def test_stale_process_record_cannot_supply_a_refreshed_heartbeat(self):
        self.commands.info["started_at"] = 1000
        self.commands.beat = 1900
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_same_pid_in_a_new_service_generation_resets_observations(self):
        self.commands.invocation = "replacement"
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_wall_clock_steps_and_suspend_do_not_reconstruct_process_identity(self):
        with patch.object(watchdog.time, "time", side_effect=AssertionError("wall clock used")):
            self.commands.beat += 3600
            self.run_watchdog()
        self.assertEqual(1, len(self.commands.restarts))

    def test_changed_service_generation_is_not_restarted(self):
        self.commands.change_on_recheck = True
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_changed_service_during_redis_confirmation_is_not_restarted(self):
        self.commands.change_during_confirmation = True
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_stopped_service_during_confirmation_is_not_restarted(self):
        self.commands.stop_during_confirmation = True
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_completed_job_is_not_restarted(self):
        self.commands.finish_on_recheck = True
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_unchanged_heartbeat_cannot_confirm_a_stale_work_snapshot(self):
        self.commands.beat = 1900
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_json_string_payload_is_supported(self):
        self.change_work(payload=json.dumps({"class": "SyncNotificationsWorker", "jid": "fake-job"}))
        self.run_watchdog()
        self.assertEqual(1, len(self.commands.restarts))

    def test_malformed_work_is_reported_without_restart(self):
        for record in ["not json", json.dumps({"payload": {"class": "SyncNotificationsWorker", "jid": "fake-job"}})]:
            with self.subTest(record=record):
                self.commands.work["thread"] = record
                with self.assertRaises(watchdog.InspectionError):
                    self.run_watchdog()
                self.assertFalse(self.commands.restarts)

    def test_invalid_execution_timestamps_are_not_used(self):
        for run_at in [None, "2399", True, 0, -1, float("nan"), float("inf")]:
            with self.subTest(run_at=run_at):
                self.change_work(run_at=run_at)
                with self.assertRaises(watchdog.InspectionError):
                    self.run_watchdog()
                self.assertFalse(self.commands.restarts)

    def test_unreachable_redis_is_not_a_reason_to_restart(self):
        self.commands.fail_redis = True
        with self.assertRaises(watchdog.InspectionError):
            self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_credentials_are_not_passed_to_redis_cli(self):
        with self.assertRaises(watchdog.InspectionError):
            self.run_watchdog("redis://user:secret@127.0.0.1:6380")
        self.assertFalse(any(argv[0] == "redis-cli" for argv in self.commands.calls))

    def test_corrupt_observations_reset_the_budget_instead_of_restarting_early(self):
        corrupt_records = [
            {"first_seen": False, "beat": 1900, "over_budget": False},
            {"first_seen": True, "beat": 1900, "over_budget": True},
            {"first_seen": 999, "beat": 1900, "over_budget": True},
            {"first_seen": 3000, "beat": 1900, "over_budget": True},
            {"first_seen": 1399, "beat": 1900, "over_budget": "yes"},
            {"first_seen": 1399, "beat": False, "over_budget": True},
            None,
        ]
        key = next(iter(self.observations["jobs"]))
        for record in corrupt_records:
            with self.subTest(record=record):
                self.observations["jobs"] = {key: record}
                self.run_watchdog()
                self.assertFalse(self.commands.restarts)
                self.assertEqual(self.clock, self.observations["jobs"][key]["first_seen"])

    def test_malformed_observation_collection_resets_safely(self):
        self.observations["jobs"] = ["invalid"]
        self.run_watchdog()
        self.assertFalse(self.commands.restarts)

    def test_restart_failure_is_reported(self):
        self.commands.fail_restart = True
        with self.assertRaises(watchdog.InspectionError):
            self.run_watchdog()
        self.assertEqual(1, len(self.commands.restarts))

    def test_restart_must_change_the_service_generation(self):
        self.commands.same_after_restart = True
        with self.assertRaises(watchdog.InspectionError):
            self.run_watchdog()


if __name__ == "__main__":
    unittest.main()
