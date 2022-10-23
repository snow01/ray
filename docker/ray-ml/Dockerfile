ARG BASE_IMAGE_TAG="nightly"
FROM rayproject/ray:$BASE_IMAGE_TAG

# We have to uninstall wrapt this way for Tensorflow compatibility
COPY requirements/requirements.txt ./
COPY requirements/requirements_dl.txt ./
COPY requirements/requirements_ml_docker.txt ./
COPY requirements/requirements_rllib.txt ./
COPY requirements/requirements_tune.txt ./
COPY requirements/requirements_train.txt ./
COPY requirements/requirements_upstream.txt ./

RUN sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub
RUN sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub

RUN sudo apt-get update; \
    sudo apt-get install -y gcc \
        cmake \
        libgtk2.0-dev \
        zlib1g-dev \
        libgl1-mesa-dev \
        unzip \
        unrar; \
    $PIP --no-cache-dir install -U pip; \
    # First, install requirements
    $PIP --no-cache-dir install -U -r requirements.txt; \
    # Then, keep requirements bounds as constraints and install remaining test dependencies
    $PIP --use-deprecated=legacy-resolver --no-cache-dir install -U \
           -c requirements.txt \
           -r requirements_rllib.txt \
           -r requirements_train.txt \
           -r requirements_tune.txt \
           -r requirements_upstream.txt; \
    # explicitly install (overwrite) pytorch with CUDA support
    $PIP --no-cache-dir install -U -r requirements_ml_docker.txt; \
    # Remove dataclasses & typing because they are included in Python > 3.6
    if [ $(python -c 'import sys; print(sys.version_info.minor)') != "6" ]; then \
        $PIP uninstall dataclasses typing -y;  \
    fi;  \
    sudo rm requirements*.txt; \
    sudo apt-get clean

# Make sure tfp is installed correctly and matches tf version.
RUN python -c "import tensorflow_probability"
