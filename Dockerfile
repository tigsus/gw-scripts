# syntax=docker/dockerfile:1

FROM linuxserver/wireguard:1.0.20210914

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="gw-scripts version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="tigsus"

# add local files
COPY /root /
