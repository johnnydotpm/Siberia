#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 path/to/App.app path/to/output.ipa" >&2
  exit 64
fi

app_path=$1
output_path=$2

if [ ! -d "$app_path" ] || [ ! -f "$app_path/Info.plist" ]; then
  echo "A built iOS .app bundle with Info.plist is required: $app_path" >&2
  exit 1
fi

output_dir=$(dirname "$output_path")
output_name=$(basename "$output_path")
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
output_path="$output_dir/$output_name"

staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/siberiagb-ipa.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT HUP INT TERM

mkdir -p "$staging_dir/Payload"
bundle_name=$(basename "$app_path")
staged_app="$staging_dir/Payload/$bundle_name"
cp -R "$app_path" "$staged_app"

# path_provider_foundation 2.6.x can add this Dart native-asset framework.
# Several on-device signers do not re-sign it correctly, so fail the build
# instead of publishing another IPA that iOS rejects after re-signing.
if [ -d "$staged_app/Frameworks/objective_c.framework" ]; then
  echo "Refusing to package unsupported objective_c.framework." >&2
  exit 1
fi

# Remove build-machine signatures and provisioning data first. Flutter emits
# some application code as single-architecture FAT Mach-O binaries. Leaving
# those binaries completely unsigned forces on-device signers to add a new
# LC_CODE_SIGNATURE command while also rewriting the FAT container, which is
# not supported reliably by every signer (including some Feather versions).
if [ -x /usr/bin/codesign ]; then
  find "$staged_app" -depth \
    -type d \( -name '*.framework' -o -name '*.appex' -o -name '*.app' \) \
    -exec /usr/bin/codesign --remove-signature {} \; 2>/dev/null || true
fi
find "$staged_app" \
  -type d -name _CodeSignature -prune -exec rm -rf {} +
find "$staged_app" \
  -type f \( -name CodeResources -o -name embedded.mobileprovision \) -delete

# ZIP permissions are not sufficient to identify every executable inside a
# bundle. Normalize the bundle and explicitly restore executable permissions
# from each nested Info.plist before signing it.
chmod -R u+rwX,go+rX "$staged_app"
find "$staged_app" -depth \
  -type d \( -name '*.framework' -o -name '*.appex' -o -name '*.app' \) -print |
while IFS= read -r bundle_path; do
  executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
    "$bundle_path/Info.plist" 2>/dev/null || true)
  if [ -n "$executable_name" ] && [ -f "$bundle_path/$executable_name" ]; then
    chmod 0755 "$bundle_path/$executable_name"
  fi
done

# Seed every code object with a valid ad-hoc signature. Feather replaces these
# signatures with the user's paid certificate, but can now update an existing
# signature slot instead of having to restructure Flutter's FAT Mach-O files.
#
# The app and its widget carry their entitlements in this signature: the
# shared app group in them is how AltStore and SideStore know to register one
# for the user's team. A `--no-codesign` build embeds no entitlements at all.
ios_dir=$(cd "$(dirname "$0")/../ios" && pwd)
entitlements_for() {
  case $(basename "$1") in
    Runner.app) echo "$ios_dir/Runner/Runner.entitlements" ;;
    SiberiaWidgetExtension.appex) echo "$ios_dir/SiberiaWidget/SiberiaWidget.entitlements" ;;
  esac
}
if [ -x /usr/bin/codesign ]; then
  find "$staged_app" -depth \
    -type d \( -name '*.framework' -o -name '*.appex' -o -name '*.app' \) -print |
  while IFS= read -r bundle_path; do
    entitlements=$(entitlements_for "$bundle_path")
    if [ -n "$entitlements" ]; then
      /usr/bin/codesign --force --sign - --timestamp=none \
        --entitlements "$entitlements" "$bundle_path"
    else
      /usr/bin/codesign --force --sign - --timestamp=none "$bundle_path"
    fi
  done
  /usr/bin/codesign --verify --deep --strict \
    "$staged_app"
  for bundle_path in "$staged_app" "$staged_app/PlugIns/SiberiaWidgetExtension.appex"; do
    if ! /usr/bin/codesign -d --entitlements - "$bundle_path" 2>/dev/null |
      grep -q 'com.apple.security.application-groups'; then
      echo "Missing the shared app group entitlement: $bundle_path" >&2
      exit 1
    fi
  done
fi
rm -f "$output_path"

# An IPA is a ZIP whose root contains Payload/AppName.app. The -y flag keeps
# framework symlinks as symlinks instead of replacing them with file contents.
(cd "$staging_dir" && /usr/bin/zip -qryXy "$output_path" Payload)

/usr/bin/unzip -tq "$output_path"
entries=$(/usr/bin/unzip -Z1 "$output_path")

if printf '%s\n' "$entries" | grep -Ev '^(Payload/|Payload$)' >/dev/null; then
  echo "IPA contains entries outside its Payload root." >&2
  exit 1
fi

if ! printf '%s\n' "$entries" | grep -Fqx "Payload/$bundle_name/Info.plist"; then
  echo "IPA is missing Payload/$bundle_name/Info.plist." >&2
  exit 1
fi

widget_plist="Payload/$bundle_name/PlugIns/SiberiaWidgetExtension.appex/Info.plist"
if ! printf '%s\n' "$entries" | grep -Fqx "$widget_plist"; then
  echo "IPA is missing the home screen widget: $widget_plist" >&2
  exit 1
fi

if printf '%s\n' "$entries" | grep -E 'embedded\.mobileprovision$' >/dev/null; then
  echo "IPA still contains a stale provisioning profile." >&2
  exit 1
fi

if printf '%s\n' "$entries" | grep -F '/Frameworks/objective_c.framework/' >/dev/null; then
  echo "IPA contains unsupported objective_c.framework." >&2
  exit 1
fi

if ! printf '%s\n' "$entries" | grep -Fqx "Payload/$bundle_name/_CodeSignature/CodeResources"; then
  echo "IPA is missing the compatibility ad-hoc signature." >&2
  exit 1
fi

echo "Created a signer-ready, ad-hoc-signed IPA payload: $output_path"
/usr/bin/unzip -Z1 "$output_path" | sed -n '1,12p'
