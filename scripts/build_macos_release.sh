#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$project_dir"
# Refresh the generated registry after pulling new or removed modules.
dart run tool/generate_modules.dart
# Additional Flutter flags (e.g. --dart-define=CRM_API_URL=...) are optional.
flutter build macos --release "$@"
app="$project_dir/build/macos/Build/Products/Release/CRM-interface.app"
codesign --verify --deep --strict "$app"
if [[ -e "$app/Contents/embedded.provisionprofile" ]]; then
  echo "Refusing to package a provisioning-profile-bound app." >&2
  exit 1
fi
package="$project_dir/dist/CRM-macos"
mkdir -p "$package"
# Replace only this script's previous output, never sources or database files.
if [[ -d "$package/CRM-interface.app" ]]; then
  rm -rf "$package/CRM-interface.app"
fi
ditto "$app" "$package/CRM-interface.app"
cp scripts/run_macos.command "$package/Запустить CRM.command"
chmod +x "$package/Запустить CRM.command"
cp docs/macos.md "$package/README.md"
ditto -c -k --sequesterRsrc --keepParent "$package" "$project_dir/dist/CRM-macos.zip"
(cd dist && shasum -a 256 CRM-macos.zip > CRM-macos.zip.sha256)
echo "App: $package/CRM-interface.app"
echo "ZIP: $project_dir/dist/CRM-macos.zip"
