#!/usr/bin/env python3
"""
Thin compatibility wrapper so the standalone script still works.
Delegates all logic to the packaged CLI entry point.
"""

from name2port.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
