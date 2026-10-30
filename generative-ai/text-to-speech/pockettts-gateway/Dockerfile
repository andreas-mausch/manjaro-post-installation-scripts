# syntax=docker/dockerfile:1
# pockettts.cpp (Vulkan) + an ffmpeg format gateway behind an OpenAI API.
# Build: docker compose build  (from this directory)

FROM archlinux:latest AS build
RUN pacman -Syu --noconfirm --needed base-devel cmake git pkgconf python glslang spirv-headers spirv-tools vulkan-headers vulkan-icd-loader shaderc
ARG PKTTS_REPO=https://github.com/ServeurpersoCom/pockettts.cpp.git
ARG PKTTS_REF=fab7972
RUN git clone ${PKTTS_REPO} /src \
 && cd /src && git checkout ${PKTTS_REF} \
 && git submodule update --init --recursive \
 && ./buildvulkan.sh
# Runtime libraries with resolved symlinks (names kept as real files).
RUN mkdir /out && cp -aL /src/build/libggml*.so* /out/ && cp /src/build/tts-server /out/

FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed vulkan-icd-loader vulkan-radeon ffmpeg python curl ca-certificates \
 && rm -rf /var/cache/pacman
COPY --from=build /out/ /usr/local/lib/
RUN mv /usr/local/lib/tts-server /usr/local/bin/tts-server
ENV LD_LIBRARY_PATH=/usr/local/lib
COPY gateway.py entrypoint.sh /opt/tts/
ENV PYTHONUNBUFFERED=1
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD curl -fsS http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/opt/tts/entrypoint.sh"]
