#!/usr/bin/env bash
# Builds dist/sd-redirect-<version>.zip, flashable in APatch / KernelSU (Linux/macOS twin of build.ps1).
# With a JDK available (javac on PATH or JAVA_HOME), also builds the toast helper module/bin/sd-redirect-toast.dex.
# Needs: zip (or python3), curl or wget for the one-time r8 download.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
src=$root/module
stage=$root/build
dist=$root/dist
tools=$root/build-cache
R8_VERSION=8.5.35

find_jdk_tool() {
  if command -v "$1" >/dev/null 2>&1; then command -v "$1"
  elif [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/$1" ]; then echo "$JAVA_HOME/bin/$1"
  fi
}

build_toast() {
  local javac java dex=$src/bin/sd-redirect-toast.dex java_src=$root/toast/SdRedirectToast.java r8
  javac=$(find_jdk_tool javac); java=$(find_jdk_tool java)
  if [ -z "$javac" ] || [ -z "$java" ]; then
    echo 'WARNING: No JDK found: packaging without the toast helper (notification fallback only).' >&2
    return
  fi
  [ -f "$dex" ] && [ "$dex" -nt "$java_src" ] && return

  mkdir -p "$tools"
  r8=$tools/r8-$R8_VERSION.jar
  if [ ! -f "$r8" ]; then
    echo "Downloading r8 $R8_VERSION (D8 dexer)..."
    local url=https://dl.google.com/dl/android/maven2/com/android/tools/r8/$R8_VERSION/r8-$R8_VERSION.jar
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$r8.part" "$url"; else wget -q -O "$r8.part" "$url"; fi
    mv "$r8.part" "$r8"
  fi

  rm -rf "$tools/classes" "$tools/dex"
  mkdir -p "$tools/classes" "$tools/dex"
  "$javac" --release 8 -nowarn -d "$tools/classes" "$java_src"
  find "$tools/classes" -name '*.class' -print0 \
    | xargs -0 "$java" -cp "$r8" com.android.tools.r8.D8 --release --min-api 30 --output "$tools/dex"
  mkdir -p "$(dirname "$dex")"
  cp -f "$tools/dex/classes.dex" "$dex"
  echo "Built $dex"
}

build_toast

version=$(sed -n 's/^version=//p' "$src/module.prop" | head -n 1 | tr -d '\r[:space:]')

rm -rf "$stage"
cp -R "$src" "$stage"
cp "$root/LICENSE" "$root/README.md" "$stage/"
mkdir -p "$dist"

# Shell scripts break on CRLF; normalize every text file to LF (binary files are left alone).
# (-i.crlf works with both GNU and BSD sed; the backups are deleted right after)
find "$stage" -type f ! -name '*.dex' -exec sed -i.crlf 's/\r$//' {} +
find "$stage" -name '*.crlf' -delete

zip=$dist/sd-redirect-$version.zip
rm -f "$zip"
if command -v zip >/dev/null 2>&1; then
  (cd "$stage" && zip -qr -X "$zip" .)
else
  (cd "$stage" && python3 -m zipfile -c "$zip" *)
fi
rm -rf "$stage"
echo "Built $zip"
