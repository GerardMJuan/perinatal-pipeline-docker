# Use the original dHCP pipeline image as the base image
FROM biomedia/dhcp-structural-pipeline:latest as dhcp_base

RUN apt-get update && \
    apt-get install -y build-essential checkinstall \
    libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev \
    libgdbm-dev libc6-dev libbz2-dev zlib1g-dev openssl libffi-dev python3-dev curl && \
    wget https://www.python.org/ftp/python/3.6.15/Python-3.6.15.tgz && \
    tar xzf Python-3.6.15.tgz && \
    cd Python-3.6.15 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.6.15* && \
    curl https://bootstrap.pypa.io/pip/3.6/get-pip.py | python3.6 - && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/bin:${PATH}"

RUN echo $PATH && \
    pip3 install --upgrade setuptools pip && \
    pip3 install numpy SimpleITK

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    bc \
    ca-certificates \
    gnupg \
    ninja-build \
    git \
    software-properties-common \
    wget \
    unzip \
    gcc \
    g++

RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
    | apt-key add - \
    && apt-add-repository -y 'deb https://apt.kitware.com/ubuntu/ bionic main' \
    && apt-get update \
    && apt-get -y install cmake=3.18.3-0kitware1 cmake-data=3.18.3-0kitware1

RUN git clone --depth 1 https://github.com/ANTsX/ANTs.git /tmp/ants/source

RUN mkdir -p /tmp/ants/build \
    && cd /tmp/ants/build \
    && mkdir -p /opt/ants \
    && git config --global url."https://".insteadOf git:// \
    && cmake \
    -GNinja \
    -DBUILD_TESTING=ON \
    -DRUN_LONG_TESTS=OFF \
    -DRUN_SHORT_TESTS=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=/opt/ants \
    /tmp/ants/source \
    && cmake --build . --parallel \
    && cd ANTS-build \
    && cmake --install .

ENV ANTSPATH="/opt/ants/bin/" \
    PATH="/opt/ants/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/ants/lib:$LD_LIBRARY_PATH"

RUN apt-get update \
    && apt install -y --no-install-recommends \
    bc \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Clone the perinatal pipeline extension repository
RUN git clone --depth 1 https://github.com/GerardMJuan/perinatal-pipeline-docker.git /tmp/perinatal-pipeline-aux3

# Copy the contents of the cloned repository to the existing structural-pipeline directory
# Grant executable permissions to all the scripts in the various directories
RUN cp -R /tmp/perinatal-pipeline-aux3/* /usr/src/structural-pipeline/ \
    && rm -rf /tmp/perinatal-pipeline-aux3 \
    && chmod +x -R /usr/src/structural-pipeline/setup_perinatal.sh \
    && chmod +x -R /usr/src/structural-pipeline/perinatal-pipeline.sh \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/pipelines/ \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/basic_scripts/ \
    && chmod +x -R /usr/src/structural-pipeline/perinatal/perinatal_scripts/scripts/ \
    && chmod +x -R /etc/fsl/fsl.sh

# Run the setup_perinatal.sh script
RUN cd /usr/src/structural-pipeline && sh setup_perinatal.sh

# Set the entrypoint for the new image
ENTRYPOINT ["/usr/src/structural-pipeline/perinatal-pipeline.sh"]
