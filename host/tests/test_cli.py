"""CLI tests over the mock transport: exit codes, CSV export, discover."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cli import nvme_tool  # noqa: E402


def test_status_exit_ok():
    assert nvme_tool.main(["status"]) == nvme_tool.EXIT_OK


def test_self_test_exit_ok():
    assert nvme_tool.main(["self-test", "--json"]) == nvme_tool.EXIT_OK


def test_queues_returns_device_error():
    # the mock answers GET_QUEUE_STATUS with ERROR -> exit code 1
    assert nvme_tool.main(["queues"]) == nvme_tool.EXIT_DEVICE_ERROR


def test_bad_port_is_transport_error():
    assert nvme_tool.main(["status", "--port", "/dev/does-not-exist-xyz"]) == nvme_tool.EXIT_TRANSPORT


def test_csv_export(tmp_path):
    out = tmp_path / "log.csv"
    assert nvme_tool.main(["counters", "--csv", str(out)]) == nvme_tool.EXIT_OK
    assert nvme_tool.main(["counters", "--csv", str(out)]) == nvme_tool.EXIT_OK
    lines = out.read_text().strip().splitlines()
    assert len(lines) == 3  # header + 2 rows
    assert lines[0].startswith("timestamp,command")


def test_discover_runs():
    assert nvme_tool.main(["discover", "--json"]) == nvme_tool.EXIT_OK
