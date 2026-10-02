#!/bin/bash
set -e

THIRDPARTY_DIR="app/src/main/cpp/thirdparty"
mkdir -p "$THIRDPARTY_DIR"
cd "$THIRDPARTY_DIR"

echo "=== Setting up OpenCV 4.1.0 Android SDK ==="
mkdir -p opencv-4.1.0-android-sdk
cd opencv-4.1.0-android-sdk
if [ ! -d "OpenCV-android-sdk" ]; then
    curl -L -o opencv.zip https://github.com/opencv/opencv/releases/download/4.1.0/opencv-4.1.0-android-sdk.zip
    unzip -q opencv.zip
    rm opencv.zip
fi
cd ..

echo "=== Setting up Boost 1.74.0 ==="
if [ ! -d "boost_1_74_0" ]; then
    curl -L -o boost.tar.gz https://archives.boost.io/release/1.74.0/source/boost_1_74_0.tar.gz
    tar -xzf boost.tar.gz
    rm boost.tar.gz
fi

echo "=== Setting up Eigen 3.2.10 ==="
if [ ! -d "eigen-3.2.10" ]; then
    curl -L -o eigen.tar.gz https://gitlab.com/libeigen/eigen/-/archive/3.2.10/eigen-3.2.10.tar.gz
    tar -xzf eigen.tar.gz
    rm eigen.tar.gz
fi

echo "=== Setting up Ceres Solver 1.13.0 ==="
if [ ! -d "ceres-solver-1.13.0" ]; then
    curl -L -o ceres.tar.gz https://github.com/ceres-solver/ceres-solver/archive/refs/tags/1.13.0.tar.gz
    tar -xzf ceres.tar.gz
    rm ceres.tar.gz
    if [ -f "ceres-solver-1.13.0/internal/ceres/schur_eliminator_impl.h" ]; then
        sed -i 's/\brandom_shuffle\b/std::random_shuffle/g' ceres-solver-1.13.0/internal/ceres/schur_eliminator_impl.h
    fi
fi

echo "=== Ensuring NDK 21.4.7075529 is installed ==="
NDK_VERSION="21.4.7075529"
SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
if [ -z "$SDK_ROOT" ]; then
    SDK_ROOT="/usr/local/lib/android/sdk"
fi

if [ ! -d "$SDK_ROOT/ndk/$NDK_VERSION" ]; then
    echo "Installing NDK $NDK_VERSION via sdkmanager..."
    yes | "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --install "ndk;$NDK_VERSION" || \
    yes | "$SDK_ROOT/tools/bin/sdkmanager" --install "ndk;$NDK_VERSION" || true
fi

if [ -d "$SDK_ROOT/ndk/$NDK_VERSION" ]; then
    ANDROID_NDK_HOME="$SDK_ROOT/ndk/$NDK_VERSION"
elif [ -z "$ANDROID_NDK_HOME" ]; then
    if [ -d "$SDK_ROOT/ndk-bundle" ]; then
        ANDROID_NDK_HOME="$SDK_ROOT/ndk-bundle"
    elif [ -d "$SDK_ROOT/ndk" ]; then
        ANDROID_NDK_HOME=$(ls -d $SDK_ROOT/ndk/* | tail -n 1)
    fi
fi

if [ -n "$ANDROID_NDK_HOME" ]; then
    echo "Using NDK at: $ANDROID_NDK_HOME"
    EIGEN_PATH="$(pwd)/eigen-3.2.10"
    CERES_PATH="$(pwd)/ceres-solver-1.13.0"

    for ABI in armeabi-v7a arm64-v8a x86 x86_64; do
        echo "Building Ceres for $ABI..."
        BUILD_DIR="/tmp/ceres_build_$ABI"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"

        cmake -B"$BUILD_DIR" -H"$CERES_PATH" \
            -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI="$ABI" \
            -DANDROID_PLATFORM=android-21 \
            -DEIGEN_INCLUDE_DIR="$EIGEN_PATH" \
            -DCMAKE_CXX_FLAGS="-std=c++14" \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_TESTING=OFF \
            -DOPENMP=OFF \
            -DMINIGLOG=ON

        cmake --build "$BUILD_DIR" --config Release --target ceres -- -j$(nproc)

        DEST_DIR="$CERES_PATH/obj/local/$ABI"
        mkdir -p "$DEST_DIR"
        cp "$BUILD_DIR/lib/libceres.a" "$DEST_DIR/"
        rm -rf "$BUILD_DIR"
    done
else
    echo "Warning: ANDROID_NDK_HOME not found. Skipping Ceres compilation step."
fi

echo "=== Setup completed successfully ==="
