"""Regénère les cultures — délègue à regenerate_all_art (même style que le reste)."""
from __future__ import annotations

import runpy
from pathlib import Path

if __name__ == "__main__":
	runpy.run_path(str(Path(__file__).with_name("regenerate_all_art.py")), run_name="__main__")
