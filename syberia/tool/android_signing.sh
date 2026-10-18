#!/bin/sh
# Signs the Android release build with the project's own key. Android installs
# an update over an app only when both carry the same signature, so every
# release has to be signed with this one key. The key is not in the
# repository: the workflows hand it over from the repository's secrets.
#
#   android_signing.sh setup
#       Writes the key and android/key.properties, which the Gradle build
#       reads, from ANDROID_KEYSTORE_BASE64 (the PKCS12 keystore) and
#       ANDROID_KEYSTORE_PASSWORD. Without them it changes nothing, and the
#       build signs with a debug key.
#
#   android_signing.sh verify path/to/app.apk
#       Says which certificate the APK is signed with. Once the key is set
#       up, any certificate but the project's fails.
#
# Run it from the app's directory, as the workflows do.

set -eu

# SHA-256 of the certificate that every published APK carries.
certificate=0f8229665bd9c484d729a01991061f27f1e3e79a381391b01574258475b42633
properties=android/key.properties

case "${1:-}" in
  setup)
    if [ -z "${ANDROID_KEYSTORE_BASE64:-}" ] ||
      [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
      echo "::warning::This repository has no Android signing key in its secrets. The APK is signed with a throwaway key and will not install over a published release."
      exit 0
    fi
    keystore="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/siberiagb-release.keystore"
    printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$keystore"
    cat > "$properties" << EOF
storeFile=$keystore
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=siberiagb
keyPassword=$ANDROID_KEYSTORE_PASSWORD
EOF
    echo "The APK will be signed with the project's key."
    ;;

  verify)
    if [ "$#" -ne 2 ]; then
      echo "Usage: $0 verify path/to/app.apk" >&2
      exit 64
    fi
    sdk=${ANDROID_HOME:?is where the Android SDK with apksigner is}
    apksigner=$(ls -d "$sdk"/build-tools/*/apksigner | sort -V | tail -n 1)
    if [ -z "$apksigner" ]; then
      echo "No apksigner under $sdk/build-tools." >&2
      exit 1
    fi
    report=$("$apksigner" verify --print-certs "$2")
    # The line begins "Signer #1 certificate" or "V2 Signer: certificate",
    # depending on the version of the tool.
    found=$(printf '%s\n' "$report" |
      sed -n 's/^.*certificate SHA-256 digest: //p' | head -n 1)
    if [ -z "$found" ]; then
      echo "apksigner named no certificate. It said:" >&2
      printf '%s\n' "$report" >&2
      exit 1
    fi
    echo "The APK is signed with the certificate $found"
    if [ ! -f "$properties" ]; then
      exit 0
    fi
    if [ "$found" != "$certificate" ]; then
      echo "::error::The APK is not signed with the project's key, whose certificate is $certificate."
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 setup | verify path/to/app.apk" >&2
    exit 64
    ;;
esac
