from __future__ import annotations

import urllib.request


def test_health_endpoint(server_url: str) -> None:
    with urllib.request.urlopen(f"{server_url}/health", timeout=5) as response:
        assert response.status == 200
        assert response.read() == b"ok"
