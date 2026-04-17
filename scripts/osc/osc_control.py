#!/usr/bin/env python3
"""
Minimal OSC-line helper for Cosmic Visualizer UDP control.

This helper sends plain-text OSC-style lines expected by OSCControlService.
Examples:
  python3 scripts/osc/osc_control.py --message "/cosmic/scene/next"
  python3 scripts/osc/osc_control.py --message "/cosmic/fractal/zoom f 1.25"
  python3 scripts/osc/osc_control.py --query-state
"""

from __future__ import annotations

import argparse
import socket
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send Cosmic Visualizer OSC UDP control lines.")
    parser.add_argument("--host", default="127.0.0.1", help="OSC host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=9000, help="OSC port (default: 9000)")
    parser.add_argument("--token", default="", help="Optional OSC auth token")
    parser.add_argument(
        "--message",
        default="",
        help="OSC line message, e.g. '/cosmic/scene/next' or '/cosmic/fractal/zoom f 1.3'",
    )
    parser.add_argument(
        "--query-state",
        action="store_true",
        help="Send '/cosmic/state/get' and wait for JSON state response.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=1.5,
        help="Response timeout in seconds for --query-state (default: 1.5)",
    )
    return parser.parse_args()


def build_line(message: str, token: str) -> str:
    msg = message.strip()
    if not msg:
        return msg
    if token.strip():
        return f"{msg} token={token.strip()}"
    return msg


def send_and_optionally_receive(host: str, port: int, line: str, timeout: float, expect_response: bool) -> int:
    payload = line.encode("utf-8")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.sendto(payload, (host, port))
        if not expect_response:
            print(f"sent: {line}")
            return 0
        sock.settimeout(timeout)
        try:
            data, _ = sock.recvfrom(65535)
        except socket.timeout:
            print("error: timed out waiting for /cosmic/state/get response", file=sys.stderr)
            return 2
    print(data.decode("utf-8", errors="replace"))
    return 0


def main() -> int:
    args = parse_args()
    if not args.query_state and not args.message.strip():
        print("error: provide --message or --query-state", file=sys.stderr)
        return 2
    line = "/cosmic/state/get" if args.query_state else args.message
    line = build_line(line, args.token)
    return send_and_optionally_receive(
        host=args.host,
        port=args.port,
        line=line,
        timeout=max(0.1, args.timeout),
        expect_response=args.query_state,
    )


if __name__ == "__main__":
    raise SystemExit(main())
