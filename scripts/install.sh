#!/bin/bash
set -e

echo "Installing Flutter..."

# Clone Flutter if not exists
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Precache
flutter precache

echo "Flutter installed: $(flutter --version)"
