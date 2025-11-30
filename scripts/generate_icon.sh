#!/bin/bash
# Generates iOS app icons for Workouts
# Usage: ./scripts/generate_icon.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="/tmp/icongen_$$"

echo "Setting up Python environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install Pillow --quiet

echo "Generating icons..."
python3 "$SCRIPT_DIR/generate_icon.py"

echo "Cleaning up..."
rm -rf "$VENV_DIR"

echo "Done!"

