#!/bin/bash
# This script is for users to build docker images locally. It is most useful for users wishing to edit the
# base-deps, ray-deps, or ray images. This script is *not* tested, so please look at the
# scripts/build-docker-images.py if there are problems with using this script.

set -Eeuox pipefail

GPU=""
WHEEL=""
BASE_IMAGE="ubuntu:focal"
WHEEL_TYPE="LOCAL"
WHEEL_URL="https://s3-us-west-2.amazonaws.com/ray-wheels/latest/ray-3.0.0.dev0-cp38-cp38-manylinux2014_x86_64.whl"
PY_VERSION="cp38"
PYTHON_VERSION_LONG="3.8"
OUTPUT_SHA=""
BUILD_DEV=""
BUILD_EXAMPLES=""
WHEEL_BUILD="YES"

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  --gpu)
    GPU="-gpu"
    BASE_IMAGE="nvidia/cuda:11.2.0-cudnn8-devel-ubuntu18.04"
    ;;
  --base-image)
    # Override for the base image.
    shift
    BASE_IMAGE=$1
    ;;
  --no-cache-build)
    NO_CACHE="--no-cache"
    ;;
  --build-development-image)
    BUILD_DEV=YES
    ;;
  --build-examples)
    BUILD_EXAMPLES=YES
    ;;
  --shas-only)
    # output the SHA sum of each build. This is useful for scripting tests,
    # especially when builds of different versions are running on the same machine.
    # It also can facilitate cleanup.
    OUTPUT_SHA=YES
    ;;
  --wheel-to-use)
    # Which wheel to use: LOCAL, REMOTE
    shift
    WHEEL_TYPE=$1
    ;;
  --wheel-url)
    # wheel url to use for remote wheel
    shift
    WHEEL_URL=$1
    ;;
  --python-version)
    # Python version to install. possible values: cp36, cp37, cp38, cp39, cp310
    shift
    PY_VERSION=$1
    ;;
  --no-wheel-build)
    shift
    WHEEL_BUILD=""
    ;;
  *)
    echo "Usage: build-docker.sh [ --gpu ] [ --base-image ] [ --no-cache-build ] [ --shas-only ] [ --build-development-image ] [ --build-examples ] [ --wheel-to-use ] [ --python-version ]"
    exit 1
    ;;
  esac
  shift
done

# TODO:
#   convert python version to numeric version
#   if wheel url based build - validate python version matches
#   if local wheel - validate wheel exists


if [ "$WHEEL_BUILD" == "YES" ]; then
  docker run -e RAY_INSTALL_JAVA=1 -e TRAVIS_COMMIT="$(git log --format="%H" -n 1)" --rm -w /ray -v "$(pwd):/ray" \
    -ti quay.io/pypa/manylinux2014_x86_64 /ray/python/build-wheel-manylinux2014.sh -p $PY_VERSION
fi


BASE_IMAGE_TAG="nightly-$PY_VERSION$GPU"

#TODO: provide wheel url / location as arg
if [ "$WHEEL_TYPE" == "LOCAL" ]; then
  WHEEL=".whl/ray-3.0.0.dev0-cp38-cp38-manylinux2014_x86_64.whl"
else
  WHEEL_DIR=$(mktemp -d)
  wget --quiet "$WHEEL_URL" -P "$WHEEL_DIR"
  WHEEL="$WHEEL_DIR/$(basename "$WHEEL_DIR"/*.whl)"
fi

# Build base-deps, ray-deps, ray, and ray-ml.
# "base-deps" "ray-deps" "ray-ml"
for IMAGE in "ray" ; do
  echo "=================================================>"
  echo "==== BUILDING rayproject/$IMAGE:$BASE_IMAGE_TAG ===="
  # BASE_IMAGE arg doesn't matter for any except except base-deps
  #--build-arg GPU="$GPU"
  BUILD_ARGS="$NO_CACHE"

  if [ "$IMAGE" == "base-deps" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg BASE_IMAGE=$BASE_IMAGE --build-arg PYTHON_VERSION=$PYTHON_VERSION_LONG"
  else
    BUILD_ARGS="$BUILD_ARGS --build-arg BASE_IMAGE_TAG=$BASE_IMAGE_TAG --build-arg WHEEL_PATH=$(basename "$WHEEL")"
  fi

  cp "$WHEEL" "docker/$IMAGE/$(basename "$WHEEL")"
  if [ "$IMAGE" == "ray-ml" ]; then
    cp "python/requirements.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_dl.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_ml_docker.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_rllib.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_tune.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_train.txt" "docker/$IMAGE/"
    cp "python/requirements/ml/requirements_upstream.txt" "docker/$IMAGE/"
  fi

  if [ "$OUTPUT_SHA" == "YES" ]; then
    IMAGE_SHA=$(docker build $BUILD_ARGS -q -t rayproject/$IMAGE:$BASE_IMAGE_TAG docker/$IMAGE)
    echo "rayproject/$IMAGE:nightly$BASE_IMAGE_TAG SHA:$IMAGE_SHA"
  else
    docker build $BUILD_ARGS -t rayproject/$IMAGE:$BASE_IMAGE_TAG docker/$IMAGE
  fi
  rm "docker/$IMAGE/$(basename "$WHEEL")"
  if [ "$IMAGE" == "ray-ml" ]; then
      rm "docker/$IMAGE/requirements"*
    fi
  echo "<================================================="
done

# Build the current Ray source
if [ "$BUILD_DEV" == "YES" ]; then
  git rev-parse HEAD >./docker/development/git-rev
  git archive -o ./docker/development/ray.tar "$(git rev-parse HEAD)"
  if [ "$OUTPUT_SHA" == "YES" ]; then
    IMAGE_SHA=$(docker build $NO_CACHE -q -t rayproject/development docker/development)
    echo "rayproject/development:latest SHA:$IMAGE_SHA"
  else
    docker build $NO_CACHE -t rayproject/development docker/development
  fi
  rm ./docker/development/ray.tar ./docker/development/git-rev
fi

if [ "$BUILD_EXAMPLES" == "YES" ]; then
  if [ "$OUTPUT_SHA" == "YES" ]; then
    IMAGE_SHA=$(docker build $NO_CACHE --build-arg BASE_IMAGE_TAG="$BASE_IMAGE_TAG" -q -t rayproject/examples docker/examples)
    echo "rayproject/examples:latest SHA:$IMAGE_SHA"
  else
    docker build $NO_CACHE --build-arg BASE_IMAGE_TAG="$BASE_IMAGE_TAG" -t rayproject/examples docker/examples
  fi
fi

#rm -rf "$WHEEL_DIR"
