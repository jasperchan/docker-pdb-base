#
# handbrake Dockerfile
#
# https://github.com/jlesage/docker-handbrake
#

# HANDBRAKE
###############################################################################

# Define software versions.
ARG HANDBRAKE_VERSION=1.10.2
ARG LIBVA_VERSION=2.22.0
ARG INTEL_VAAPI_DRIVER_VERSION=2.4.1
ARG GMMLIB_VERSION=22.8.1
ARG INTEL_MEDIA_DRIVER_VERSION=25.2.6
ARG INTEL_MEDIA_SDK_VERSION=23.2.2
ARG INTEL_ONEVPL_GPU_RUNTIME_VERSION=25.2.6
ARG CPU_FEATURES_VERSION=0.9.0

# Define software download URLs.
ARG HANDBRAKE_URL=https://github.com/HandBrake/HandBrake/releases/download/${HANDBRAKE_VERSION}/HandBrake-${HANDBRAKE_VERSION}-source.tar.bz2
ARG LIBVA_URL=https://github.com/intel/libva/releases/download/${LIBVA_VERSION}/libva-${LIBVA_VERSION}.tar.bz2
ARG INTEL_VAAPI_DRIVER_URL=https://github.com/intel/intel-vaapi-driver/releases/download/${INTEL_VAAPI_DRIVER_VERSION}/intel-vaapi-driver-${INTEL_VAAPI_DRIVER_VERSION}.tar.bz2
ARG GMMLIB_URL=https://github.com/intel/gmmlib/archive/intel-gmmlib-${GMMLIB_VERSION}.tar.gz
ARG INTEL_MEDIA_DRIVER_URL=https://github.com/intel/media-driver/archive/intel-media-${INTEL_MEDIA_DRIVER_VERSION}.tar.gz
ARG INTEL_MEDIA_SDK_URL=https://github.com/Intel-Media-SDK/MediaSDK/archive/intel-mediasdk-${INTEL_MEDIA_SDK_VERSION}.tar.gz
ARG INTEL_ONEVPL_GPU_RUNTIME_URL=https://github.com/oneapi-src/oneVPL-intel-gpu/archive/refs/tags/intel-onevpl-${INTEL_ONEVPL_GPU_RUNTIME_VERSION}.tar.gz
ARG CPU_FEATURES_URL=https://github.com/google/cpu_features/archive/refs/tags/v${CPU_FEATURES_VERSION}.tar.gz

# Set to 'max' to keep debug symbols.
ARG HANDBRAKE_DEBUG_MODE=none

# Get Dockerfile cross-compilation helpers.
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

# Build HandBrake.
FROM --platform=$BUILDPLATFORM alpine:3.20 AS handbrake
ARG TARGETPLATFORM
ARG HANDBRAKE_VERSION
ARG HANDBRAKE_URL
ARG HANDBRAKE_DEBUG_MODE
ARG LIBVA_URL
ARG INTEL_VAAPI_DRIVER_URL
ARG GMMLIB_URL
ARG INTEL_MEDIA_DRIVER_URL
ARG INTEL_MEDIA_SDK_URL
ARG INTEL_ONEVPL_GPU_RUNTIME_URL
COPY --from=xx / /
COPY src/handbrake /build
RUN /build/build.sh \
    "$HANDBRAKE_VERSION" \
    "$HANDBRAKE_URL" \
    "$HANDBRAKE_DEBUG_MODE" \
    "$LIBVA_URL" \
    "$INTEL_VAAPI_DRIVER_URL" \
    "$GMMLIB_URL" \
    "$INTEL_MEDIA_DRIVER_URL" \
    "$INTEL_MEDIA_SDK_URL" \
    "$INTEL_ONEVPL_GPU_RUNTIME_URL"
RUN xx-verify \
    /tmp/handbrake-install/usr/bin/HandBrakeCLI

# Build cpu_features.
FROM --platform=$BUILDPLATFORM alpine:3.20 AS cpu_features
ARG TARGETPLATFORM
ARG CPU_FEATURES_URL
COPY --from=xx / /
COPY src/cpu_features /build
RUN /build/build.sh "$CPU_FEATURES_URL"
RUN xx-verify /tmp/cpu_features-install/bin/list_cpu_features

# FFMPEG
# https://dev.to/ethand91/using-a-newer-version-of-ffmpeg-with-docker-3b69
# https://github.com/wader/static-ffmpeg
###############################################################################

FROM --platform=$BUILDPLATFORM jasperchan/ffmpeg-static:latest AS ffmpeg


# CURL (https://github.com/lwthiker/curl-impersonate)
###############################################################################

FROM --platform=$BUILDPLATFORM lwthiker/curl-impersonate:0.6.1-chrome AS curl


# FINAL
###############################################################################

# Pull base image with Node.js 22.
FROM --platform=$BUILDPLATFORM node:22-alpine3.20

# Copy helpers.
COPY scripts/* /usr/local/bin/

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN \
    add-pkg \
    libstdc++ \
    libgudev \
    libnotify \
    libsamplerate \
    libass \
    libdrm \
    jansson \
    xz \
    numactl \
    libturbojpeg \
    # Media codecs:
    libtheora \
    lame-libs \
    opus \
    libvorbis \
    speex \
    libvpx \
    x264-libs \
    # For QSV detection
    pciutils \
    # To read encrypted DVDs
    libdvdcss \
    # A font is needed.
    font-cantarell \
    # For main, big icons:
    librsvg \
    # For all other small icons:
    adwaita-icon-theme \
    # For optical drive listing:
    lsscsi \
    # For watchfolder
    bash \
    coreutils \
    findutils \
    expect

# Add files.
COPY --from=handbrake /tmp/handbrake-install /
COPY --from=cpu_features /tmp/cpu_features-install/bin/list_cpu_features /usr/bin/
COPY --from=curl /usr/local/ /usr/local/
COPY --from=ffmpeg /ffmpeg /usr/local/bin/
COPY --from=ffmpeg /ffprobe /usr/local/bin/

