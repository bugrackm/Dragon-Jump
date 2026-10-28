#!/usr/bin/env python3
"""Retired bootstrap entry point for the hand-authored ORA master."""

from __future__ import annotations


def main() -> None:
    raise SystemExit(
        "make_starter_ora.py is retired: rig_master.ora is the hand-authored source of truth "
        "and must not be regenerated or overwritten"
    )


if __name__ == "__main__":
    main()
