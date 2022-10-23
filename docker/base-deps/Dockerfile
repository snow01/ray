# The base-deps Docker image installs main libraries needed to run Ray

# The GPU options are NVIDIA CUDA developer images.
ARG BASE_IMAGE="ubuntu:focal"
FROM ${BASE_IMAGE}
# FROM directive resets ARG
ARG BASE_IMAGE
# If this arg is not "autoscaler" then no autoscaler requirements will be included
ARG AUTOSCALER="autoscaler"
ENV TZ=America/Los_Angeles
# TODO(ilr) $HOME seems to point to result in "" instead of "/home/ray"
ENV PATH "/home/ray/anaconda3/bin:$PATH"
ARG DEBIAN_FRONTEND=noninteractive

# it's better not to set this arg default and always expect value
ARG PYTHON_VERSION
# =3.7.7

RUN set -eux; echo "Python Version: $PYTHON_VERSION"

RUN set -eux; \
    apt-get update -y; \
    apt-get upgrade -y ; \
    apt-get install -y --no-install-recommends \
            sudo \
            tzdata \
            git \
            libjemalloc-dev \
            wget  \
            cmake  \
            g++  \
            zlib1g-dev \
            libsasl2-modules-sql \
            $(if [ "$AUTOSCALER" = "autoscaler" ]; then echo \
            tmux  \
            screen  \
            rsync  \
            openssh-client  \
            gnupg fi);\
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean

# create a non sudo 'ray' user
ARG RAY_UID=1000
ARG RAY_GID=100
ENV HOME=/home/ray

RUN set -eux; \
    useradd -ms /bin/bash -d /home/ray ray --uid $RAY_UID --gid $RAY_GID; \
    usermod -aG sudo ray; \
    echo 'ray ALL=NOPASSWD: ALL' >> /etc/sudoers

USER $RAY_UID

# install miniconda
ENV CONDA_DIR $HOME/anaconda3
ARG CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
RUN set -eux; \
    wget --no-check-certificate -quiet CONDA_URL -O /tmp/miniconda.sh; \
    /bin/bash /tmp/miniconda.sh -b -u -p $CONDA_DIR

# initialise conda
ENV PATH=$CONDA_DIR/bin:$PATH
ENV CONDA_BIN=$CONDA_DIR/bin/conda
ENV PIP=$CONDA_DIR/bin/pip
ENV PYTHON=$CONDA_DIR/bin/python
RUN set -eux; \
	$CONDA_BIN init ; \
	echo 'export PATH=$CONDA_DIR/bin:$PATH' >> $HOME/.bashrc ; \
	rm /tmp/miniconda.sh

RUN set -eux; \
    $CONDA_BIN install -y libgcc python=$PYTHON_VERSION; \
    $CONDA_BIN clean -y --all; \
    $PIP install --no-cache-dir \
        flatbuffers \
        cython==0.29.26 \
        # Necessary for Dataset to work properly.
        numpy\>=1.20 \
        psutil

# To avoid the following error on Jenkins:
# AttributeError: 'numpy.ufunc' object has no attribute '__module__' \
RUN set -eux; \
    $PIP uninstall -y dask; \
    # We install cmake temporarily to get psutil
    sudo apt-get autoremove -y cmake zlib1g-dev \
        # We keep g++ on GPU images, because uninstalling removes CUDA Devel tooling
        $(if [ "$BASE_IMAGE" = "ubuntu:focal" ]; then echo g++; fi)

# Either install kubectl or remove wget
RUN set -eux; \
    (if [ "$AUTOSCALER" = "autoscaler" ]; then \
        wget -O - -q https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -; \
        sudo touch /etc/apt/sources.list.d/kubernetes.list; \
        echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list; \
        sudo apt-get update; \
        sudo apt-get install kubectl; \
    else  \
      sudo apt-get autoremove -y wget; \
    fi;)

# clean
RUN set -eux; \
    sudo rm -rf /var/lib/apt/lists/*; \
    sudo apt-get clean

RUN set -eux; $PYTHON --version

WORKDIR $HOME