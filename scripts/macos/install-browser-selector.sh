#!/usr/bin/env bash
set -eu -o pipefail

this_dir=$(dirname "$(readlink -f "$BASH_SOURCE")")
APP_SRC="$this_dir/browser-selector.applescript"
APP_DEST="$HOME/Applications/BrowserSelector.app"
PLIST="$APP_DEST/Contents/Info.plist"
BUNDLE_ID="com.user.browser-selector"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ -d "$APP_DEST" ]]; then
    exit 0
fi

echo "Installing $(basename "$APP_DEST")..."

mkdir -p "$HOME/Applications"
osacompile -o "$APP_DEST" "$APP_SRC"

/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSBackgroundOnly bool true" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string 'Browser Selector'" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string http" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:1 string https" "$PLIST"

"$LSREGISTER" -f "$APP_DEST"

echo "  - BrowserSelector.app installed to ~/Applications/"
