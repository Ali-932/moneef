#!/usr/bin/env bash
# Run from any directory. Screenshots render actual Flutter routes with a
# fixture-backed native bridge; any layout exception fails the suite.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze --no-pub
flutter test --exclude-tags screenshots --reporter expanded
flutter test test/screenshots --update-goldens --tags screenshots --reporter expanded
