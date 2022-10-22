ARG IMAGE_TAG="nightly"
FROM rayproject/ray-deps:$IMAGE_TAG
ARG WHEEL_PATH
ARG FIND_LINKS_PATH=".whl"
# For Click
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
COPY $WHEEL_PATH .
COPY $FIND_LINKS_PATH $FIND_LINKS_PATH
RUN $HOME/anaconda3/bin/pip --no-cache-dir install `basename $WHEEL_PATH`[all] \
--find-links $FIND_LINKS_PATH && sudo rm `basename $WHEEL_PATH`
