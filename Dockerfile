FROM ubuntu:18.04

# Install required packages
RUN apt-get update && \
  apt-get upgrade -y -q && \
  apt-get install -y -q build-essential \
  bc \
  libelf-dev \
  libssl-dev \
  flex \
  bison \
  kmod \
  cpio \
  rsync \
  curl \
  binutils-aarch64-linux-gnu \
  gcc-aarch64-linux-gnu \
  dwarves \
  python3

# Example: 4.14.304
ARG KERNEL_VERSION 

# Download Linux sources
WORKDIR /cooper/src
RUN KERNEL_MAJOR="$(echo "${KERNEL_VERSION}" | cut -d'.' -f1)"; \
  curl -sSLo linux-${KERNEL_VERSION}.tar.gz \
  http://mirrors.edge.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.gz && \
  tar zxf linux-${KERNEL_VERSION}.tar.gz

WORKDIR /configs
ADD x86_64_config /configs/x86_64
ADD arm64_config /configs/arm64

ARG ARCH
ARG CROSS_COMPILE

# Build Linux kernel
WORKDIR /cooper/src/linux-${KERNEL_VERSION}
RUN cp /configs/${ARCH} .config
RUN make ARCH=${ARCH} olddefconfig
RUN make ARCH=${ARCH} clean
RUN make ARCH=${ARCH} -j $(nproc) deb-pkg

# Extract headers into a tarball
WORKDIR /cooper
RUN DEB_ARCH=$(echo ${ARCH} | sed 's/x86_64/amd64/g'); dpkg -x src/linux-headers-${KERNEL_VERSION}_${KERNEL_VERSION}-1_${DEB_ARCH}.deb .

# Remove broken symlinks
RUN find usr/src/linux-headers-${KERNEL_VERSION} -xtype l -exec rm {} +

# Remove uneeded files to reduce size
# Keep only:
# - usr/src/linux-headers-x.x.x/include
# - usr/src/linux-headers-x.x.x/arch/${ARCH}
# This reduces the size by a little over 2x.
RUN rm -rf usr/share
RUN find usr/src/linux-headers-${KERNEL_VERSION} -maxdepth 1 -mindepth 1 ! -name include ! -name arch -type d \
  -exec rm -rf {} +
RUN find usr/src/linux-headers-${KERNEL_VERSION}/arch -maxdepth 1 -mindepth 1 ! -name $(echo ${ARCH} | sed 's/x86_64/x86/g') -type d -exec rm -rf {} +
RUN tar zcf linux-headers-${ARCH}-${KERNEL_VERSION}.tar.gz usr

VOLUME /output
CMD ["sh", "-c", "cp linux-headers-*.tar.gz /output/"]
