FROM ubuntu:18.04 AS builder

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               locales \
               git \
               scons \
               python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Set up locale

RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8

# Cacti

WORKDIR $BUILD_DIR

COPY src/cacti $BUILD_DIR/cacti

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd cacti \
    && make \
    && chmod -R 777 .

# Build and install timeloop

WORKDIR $BUILD_DIR

COPY src/timeloop $BUILD_DIR/timeloop

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
               libboost-dev \
               libboost-iostreams-dev \
               libboost-serialization-dev \
               libyaml-cpp-dev \
               libncurses5-dev \
               libtinfo-dev \
               libgpm-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd ./timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd .. \
    && scons --static --accelergy \
    && cp build/timeloop-mapper  /usr/local/bin \
    && cp build/timeloop-metrics /usr/local/bin \
    && cp build/timeloop-model   /usr/local/bin

#
# Main image
#
FROM ubuntu:18.04

LABEL maintainer="emer@csail.mit.edu"

# Arguments
ARG BUILD_DATE
ARG VCS_REF
ARG BUILD_VERSION

# Labels
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="jsemer/timeloop-accelergy-tutorial"
LABEL org.label-schema.description="Tutorial exercises for Timeloop/Accelergy tools"
LABEL org.label-schema.url="http://accelergy.mit.edu/"
LABEL org.label-schema.vcs-url="https://github.com/jsemer/timeloop-accelergy-tutorial"
LABEL org.label-schema.vcs-ref=$VCS_REF
LABEL org.label-schema.vendor="Emer"
LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.docker.cmd="docker run -it --rm -v ~/tutorial:/home/tutorial jsemer/timeloop-accelergy-tutorial"

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               locales \
               git \
               python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd tutorial \
    && useradd -m -d /home/tutorial -c "Tutorial User Account" -s /usr/sbin/nologin -g tutorial tutorial \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Set up locale

RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8

# Get tools built in other containers

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-mapper  /usr/local/bin
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-metrics /usr/local/bin
COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop-model  /usr/local/bin
COPY --from=builder  $BUILD_DIR/cacti/cacti /usr/local/bin

# Get all source

WORKDIR $BUILD_DIR

COPY src/ $BUILD_DIR/


# Accelergy

WORKDIR $BUILD_DIR

# Note source for accelergy was copied in above

COPY --from=builder  $BUILD_DIR/cacti /usr/local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti

RUN pip3 install setuptools \
    && pip3 install wheel \
    && pip3 install libconf \
    && pip3 install numpy \
    && cd accelergy \
    && pip3 install . \
    && cd .. \
    && cd accelergy-aladdin-plug-in \
    && pip3 install . \
    && cd .. \
    && cd accelergy-cacti-plug-in \
    && pip3 install . \
    && chmod 777 /usr/local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti

# Exercises

WORKDIR $BUILD_DIR

# Actual exercises were copied in above
COPY ./bin/refresh-exercises /usr/local/bin

# Set up entrypoint

COPY docker-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /home/tutorial
CMD ["bash"]
