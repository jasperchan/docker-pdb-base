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

# Pull base image.
FROM --platform=$BUILDPLATFORM alpine:3.19

# Build NodeJS.
ENV NODE_VERSION 14.21.3
RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
    libstdc++ \
    && apk add --no-cache --virtual .build-deps \
    curl \
    && ARCH= OPENSSL_ARCH='linux*' && alpineArch="$(apk --print-arch)" \
    && case "${alpineArch##*-}" in \
    x86_64) ARCH='x64' CHECKSUM="39c334bd7ef3a6e5a5a396e08b3edbe335d86161bbfba222c75aa4a3518af942" OPENSSL_ARCH=linux-x86_64;; \
    x86) OPENSSL_ARCH=linux-elf;; \
    aarch64) OPENSSL_ARCH=linux-aarch64;; \
    arm*) OPENSSL_ARCH=linux-armv4;; \
    ppc64le) OPENSSL_ARCH=linux-ppc64le;; \
    s390x) OPENSSL_ARCH=linux-s390x;; \
    *) ;; \
    esac \
    && if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
    else \
    echo "Building from source" \
    # backup build
    && apk add --no-cache --virtual .build-deps-full \
    binutils-gold \
    g++ \
    gcc \
    gnupg \
    libgcc \
    linux-headers \
    make \
    python3 \
    # use pre-existing gpg directory, see https://github.com/nodejs/docker-node/pull/1895#issuecomment-1550389150
    && export GNUPGHOME="$(mktemp -d)" \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
    ; do \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
    fi \
    && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
    # Remove unused OpenSSL headers to save ~34MB. See this NodeJS issue: https://github.com/nodejs/node/issues/46451
    && find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} \; \
    && apk del .build-deps \
    # smoke tests
    && node --version \
    && npm --version

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

