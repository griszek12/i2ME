#!/bin/bash
set -e
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SDK_KIND=${1:-iphoneos}
ARCH=${2:-armv7}
SDK=$("$DEVELOPER_DIR/usr/bin/xcodebuild" -version -sdk "$SDK_KIND" Path)
CC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
mkdir -p "build/$ARCH"
MIN_FLAG=-miphoneos-version-min=5.0
[[ "$SDK_KIND" == iphonesimulator ]] && MIN_FLAG=-mios-simulator-version-min=5.0
FLAGS=(-arch "$ARCH" -isysroot "$SDK" "$MIN_FLAG" -std=gnu99 -O1 -g -fblocks -w
 -DM3G_TARGET_GENERIC -ICompat -Iminijvm/jvm -Iminijvm/utils -Iminijvm/utils/https -Iminijvm/utils/https/mbedtls/include -INativeBridge -INativeBridge/m3g -INativeBridge/m3g/inc -include Compat/stdatomic.h)
objects=()
while IFS= read -r source; do
 obj="build/$ARCH/$(echo "$source" | tr '/.' '__').o"
 if [[ ! -f "$obj" || "$source" -nt "$obj" ]]; then
   echo "[compile $ARCH] $source"
   extra=(); [[ "$source" == *.m ]] && extra=(-fobjc-arc)
   "$CC" "${FLAGS[@]}" "${extra[@]}" -c "$source" -o "$obj"
 fi
 objects+=("$obj")
done < <({ find minijvm Compat NativeBridge -name '*.c' -o -name '*.m' | grep -v '/m3g/src/' | grep -v '/sljit/'; printf '%s\n' NativeBridge/m3g/src/m3g_core.c NativeBridge/m3g/src/m3g_ios.c NativeBridge/m3g/src/m3g_ios_gl.c; } | sort)
echo "[compile complete $ARCH] ${#objects[@]} objects"
if [[ -f App/main.m ]]; then
 "$CC" "${FLAGS[@]}" -fobjc-arc App/*.m "${objects[@]}" -o "build/$ARCH/LegacyJ2ME" -framework UIKit -framework Foundation -framework CoreGraphics -framework CoreText -framework ImageIO -framework AVFoundation -framework AudioToolbox -framework OpenGLES -framework QuartzCore -lz -lpthread -lm
 mkdir -p "build/$ARCH/LegacyJ2ME.app"
 cp "build/$ARCH/LegacyJ2ME" App/Info.plist Resources/*.jar "build/$ARCH/LegacyJ2ME.app/"
 cp Resources/Languages.plist "build/$ARCH/LegacyJ2ME.app/"
 cp Resources/Icon*.png "build/$ARCH/LegacyJ2ME.app/"
 if [[ -d Licenses ]]; then cp -R Licenses "build/$ARCH/LegacyJ2ME.app/"; fi
 if [[ -f THIRD_PARTY.md ]]; then cp THIRD_PARTY.md "build/$ARCH/LegacyJ2ME.app/"; fi
 if [[ -f Resources/gs_instruments.sf2 ]]; then cp Resources/gs_instruments.sf2 "build/$ARCH/LegacyJ2ME.app/"; fi
 echo "[app ready] build/$ARCH/LegacyJ2ME.app"
fi
