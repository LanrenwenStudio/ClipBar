import json
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.request import Request, urlopen

import clipbar_backend as backend


class ParserTests(unittest.TestCase):
    def test_codex(self):
        snapshot = backend.parse_codex({
            "plan_type": "plus",
            "rate_limit": {
                "primary_window": {"used_percent": 25, "reset_after_seconds": 3600},
                "secondary_window": {"used_percent": 80, "reset_after_seconds": 86400},
            },
        })
        self.assertEqual(snapshot["windows"][0]["remainingPercent"], 75)
        self.assertEqual(snapshot["windows"][1]["remainingPercent"], 20)

    def test_gemini_buckets(self):
        snapshot = backend.parse_gemini({
            "buckets": [
                {"modelId": "gemini-2.5-pro", "remainingFraction": 0.42},
            ]
        })
        self.assertEqual(snapshot["windows"][0]["remainingPercent"], 42)

    def test_xai_plan_and_product(self):
        snapshot = backend.parse_xai({
            "monthlyLimit": 15000,
            "creditUsagePercent": 12,
            "productUsage": [{"product": "Grok", "usagePercent": 30}],
        })
        self.assertEqual(snapshot["planType"], "SuperGrok")
        self.assertEqual(snapshot["windows"][0]["remainingPercent"], 88)

    def test_store_keeps_last_success_on_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            store = backend.SnapshotStore(str(Path(directory) / "snapshot.json"))
            store.record_success([{"account": {"id": "one"}, "snapshot": {"windows": []}}])
            store.record_failure("network down")
            data = store.read()
            self.assertEqual(len(data["accounts"]), 1)
            self.assertEqual(data["error"], "network down")


class HTTPTests(unittest.TestCase):
    def test_snapshot_requires_token(self):
        with tempfile.TemporaryDirectory() as directory:
            store = backend.SnapshotStore(str(Path(directory) / "snapshot.json"))
            server = backend.BackendServer(("127.0.0.1", 0), store, "secret")
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f"http://127.0.0.1:{server.server_port}/v1/snapshot"
            with self.assertRaises(Exception):
                urlopen(url)
            request = Request(url, headers={"Authorization": "Bearer secret"})
            with urlopen(request) as response:
                payload = json.load(response)
            self.assertEqual(payload["accounts"], [])
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_refresh_requires_token_and_runs_poller(self):
        class FakePoller:
            def refresh_once(self):
                store.record_success([{"account": {"id": "fresh"}, "snapshot": {"windows": []}}])
                return True

        with tempfile.TemporaryDirectory() as directory:
            store = backend.SnapshotStore(str(Path(directory) / "snapshot.json"))
            server = backend.BackendServer(("127.0.0.1", 0), store, "secret", FakePoller())
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f"http://127.0.0.1:{server.server_port}/v1/refresh"
            with self.assertRaises(Exception):
                urlopen(Request(url, method="POST"))
            request = Request(url, method="POST", headers={"Authorization": "Bearer secret"})
            with urlopen(request) as response:
                payload = json.load(response)
            self.assertEqual(payload["accounts"][0]["account"]["id"], "fresh")
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_shared_refresh_interval_can_be_read_and_updated(self):
        with tempfile.TemporaryDirectory() as directory:
            store = backend.SnapshotStore(str(Path(directory) / "snapshot.json"))
            settings = backend.BackendSettingsStore(str(Path(directory) / "settings.json"), 600)

            class FakePoller:
                def __init__(self):
                    self.interval = 600

                def get_interval(self):
                    return self.interval

                def set_interval(self, seconds):
                    self.interval = seconds

            poller = FakePoller()
            server = backend.BackendServer(("127.0.0.1", 0), store, "secret", poller, settings)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f"http://127.0.0.1:{server.server_port}/v1/settings"
            headers = {"Authorization": "Bearer secret"}
            request = Request(url, headers=headers)
            with urlopen(request) as response:
                self.assertEqual(json.load(response)["refresh_interval_seconds"], 600)
            request = Request(
                url,
                data=json.dumps({"refresh_interval_seconds": 180}).encode(),
                headers={**headers, "Content-Type": "application/json"},
                method="PUT",
            )
            with urlopen(request) as response:
                self.assertEqual(json.load(response)["refresh_interval_seconds"], 180)
            self.assertEqual(poller.interval, 180)
            self.assertEqual(settings.read_interval(), 180)
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
