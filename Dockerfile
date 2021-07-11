# EPICS ADCore Dockerfile
# Adds the Area Detector base support required by all AD images
ARG REGISTRY=ghcr.io/epics-containers
ARG MODULES_VERSION=4.41r3.0

##### build stage ##############################################################

FROM ${REGISTRY}/epics-modules:${MODULES_VERSION} AS developer

# install additional packages
USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libblosc-dev \
    libhdf5-dev \
    libjpeg-dev \
    libtiff-dev \
    libxml2-dev \
    pkg-config \
    p7zip-full \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# add the kafka client library
ENV LIBKAFKA_VERSION=1.7.0
RUN busybox wget https://github.com/edenhill/librdkafka/archive/v${LIBKAFKA_VERSION}.tar.gz \
                -O - | tar xzf - && \
    cd librdkafka-${LIBKAFKA_VERSION}/ && \
    ./configure --prefix=/usr && \
    make -j && make install && cd .. && rm -fr librdkafka-${LIBKAFKA_VERSION}

USER ${USERNAME}

# get additional support modules
ENV ADSUPPORT_VERSION=R1-9-1
ENV ADCORE_VERSION=R3-10
ENV ADKAFKA_VERSION=0.1
ENV ADKAFKA_DIR=${SUPPORT}/ADKafka-0-1

RUN python3 module.py add areaDetector ADSupport ADSUPPORT ${ADSUPPORT_VERSION}
RUN python3 module.py add areaDetector ADCore ADCORE ${ADCORE_VERSION}
RUN python3 module.py add dls-controls ADKafka ADKAFKA ${ADKAFKA_VERSION}

# add CONFIG_SITE.linux and RELEASE.local
COPY --chown=${USER_UID}:${USER_GID} configure ${SUPPORT}/ADSupport-${ADSUPPORT_VERSION}/configure
COPY --chown=${USER_UID}:${USER_GID} configure ${SUPPORT}/ADCore-${ADCORE_VERSION}/configure
COPY --chown=${USER_UID}:${USER_GID} configure ${ADKAFKA_DIR}/configure

# update dependencies and build
RUN python3 module.py dependencies
RUN make -j -C  ${SUPPORT}/ADSupport-${ADSUPPORT_VERSION} && \
    make -j -C  ${SUPPORT}/ADCore-${ADCORE_VERSION} && \
    make -j -C  ${ADKAFKA_DIR} && \
    make -j clean

##### runtime stage ############################################################

FROM ${REGISTRY}/epics-modules:${MODULES_VERSION}.run AS runtime

# install runtime libraries from additional packages section above
USER root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libblosc1 \
    libhdf5-cpp-103 \
    libjpeg9 \
    libtiff5 \
    libxml2 \
    && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}