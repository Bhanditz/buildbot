#!/bin/bash
set -ex

PATH=`pwd`/depot_tools:"$PATH"
cd src

GSUTIL=$HOME/google-cloud-sdk/bin/gsutil
GCLOUD=$HOME/google-cloud-sdk/bin/gcloud

GIT_REVISION=`git rev-parse HEAD`

$GCLOUD auth activate-service-account --key-file ../gcloud_key_file.json

if [ $TRAVIS_OS_NAME = "linux" ]; then
  if [ $BUILD_TARGET = "device" ]; then
    ./sky/tools/gn --release --android --enable-firebase --enable-gcm
    ninja -C out/android_Release apks/SkyShell.apk flutter.mojo sky/services/gcm sky/services/firebase
    STORAGE_BASE_URL=gs://mojo_infra/flutter/$GIT_REVISION/android-arm

    # TODO(mpcomplete): stop bundling classes.dex once
    # https://github.com/flutter/flutter/pull/1263 lands.
    zip -j /tmp/artifacts.zip \
      build/android/ant/chromium-debug.keystore \
      out/android_Release/apks/SkyShell.apk \
      out/android_Release/flutter.mojo \
      out/android_Release/gen/sky/shell/shell/classes.dex.jar \
      out/android_Release/gen/sky/shell/shell/classes.dex \
      out/android_Release/gen/sky/shell/shell/shell/libs/armeabi-v7a/libsky_shell.so \
      out/android_Release/icudtl.dat

    $GSUTIL cp /tmp/artifacts.zip $STORAGE_BASE_URL/artifacts.zip

    # Upload GCM service libraries.
    $GSUTIL cp out/android_Release/gen/sky/services/gcm/gcm_lib.dex.jar \
      $STORAGE_BASE_URL/gcm/gcm_lib.dex.jar
    $GSUTIL cp out/android_Release/gen/sky/services/gcm/interfaces_java.dex.jar \
      $STORAGE_BASE_URL/gcm/interfaces_java.dex.jar

    # Upload Firebase service libraries.
    $GSUTIL cp out/android_Release/gen/sky/services/firebase/firebase_lib.dex.jar \
      $STORAGE_BASE_URL/firebase/firebase_lib.dex.jar
    $GSUTIL cp out/android_Release/gen/sky/services/firebase/interfaces_java.dex.jar \
      $STORAGE_BASE_URL/firebase/interfaces_java.dex.jar
  fi

  if [ $BUILD_TARGET = "host" ]; then
    ./sky/tools/gn --release
    ninja -C out/Release
    STORAGE_BASE_URL=gs://mojo_infra/flutter/$GIT_REVISION/linux-x64
    zip -j /tmp/artifacts.zip \
      out/Release/flutter.mojo \
      out/Release/icudtl.dat \
      out/Release/sky_shell \
      out/Release/sky_snapshot
    $GSUTIL cp /tmp/artifacts.zip $STORAGE_BASE_URL/artifacts.zip
  fi
fi

if [ $TRAVIS_OS_NAME = "osx" ]; then
  if [ $BUILD_TARGET = "device" ]; then
    # ./sky/tools/gn --ios --release
    # ninja -C out/ios_Release
    # STORAGE_BASE_URL=gs://mojo_infra/flutter/$GIT_REVISION/ios-arm64
    # pushd out/ios_Release
    # zip -r /tmp/artifacts.zip Flutter
    # popd
    # $GSUTIL cp /tmp/artifacts.zip $STORAGE_BASE_URL/artifacts.zip
    exit 0
  fi

  if [ $BUILD_TARGET = "host" ]; then
    ./sky/tools/gn --release
    ninja -C out/Release sky_snapshot
    STORAGE_BASE_URL=gs://mojo_infra/flutter/$GIT_REVISION/darwin-x64
    zip -j /tmp/artifacts.zip out/Release/sky_snapshot
    $GSUTIL cp /tmp/artifacts.zip $STORAGE_BASE_URL/artifacts.zip
  fi
fi
