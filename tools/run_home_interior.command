#!/bin/zsh -l
set -e
cd -- "${0:A:h:h}"
interior_flutter="$(command -v flutter || true)"
if [[ -z "$interior_flutter" ]]; then
  interior_flutter="/Users/cankaynar/development/flutter/bin/flutter"
fi
exec "$interior_flutter" run -d macos -t lib/tools/home_interior_main.dart
