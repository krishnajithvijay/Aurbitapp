#!/bin/bash
set -e

echo "Building Flutter web app..."

# Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Enable web
flutter config --enable-web

# Get dependencies  
flutter pub get

# Build for web with CanvasKit renderer
flutter build web --release --web-renderer canvaskit --base-href "/"

echo "Build complete!"
