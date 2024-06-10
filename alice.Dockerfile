FROM debian:stable-slim as source 

ARG BUILD_VERSION
ARG ARCHIVE_URL=https://github.com/alice-lg/alice-lg/archive

WORKDIR /app 
RUN test -n "${BUILD_VERSION}" \
    && apt-get update \
    && apt-get install -y curl 

RUN test -n "${BUILD_VERSION}" \
    && curl -L "${ARCHIVE_URL}/refs/tags/${BUILD_VERSION}.tar.gz" -o /tmp/alice-lg.tar.gz \
    && tar xzf /tmp/alice-lg.tar.gz --strip 1 -C /app 




FROM node:latest as ui-build

COPY --from=source /app/ui /app/ui

RUN cd /app/ui \
    && yarn install \
    && yarn build



FROM golang:1.21 as backend 

WORKDIR /src/alice-lg
COPY --from=source /app/go.mod .
COPY --from=source /app/go.sum .
RUN go mod download

COPY --from=source /app /src/alice-lg

COPY --from=ui-build /app/ui/build ui/build

WORKDIR /src/alice-lg/cmd/alice-lg
RUN sed -i '/^alpine:/,/$(PROG)-linux-$(ARCH)/ s/go build/go build -tags timetzdata/' Makefile && \
    make alpine && \
    cat Makefile
# RUN make alpine




# FROM alpine:latest
FROM scratch

# RUN apk add -U tzdata
COPY --from=backend /src/alice-lg/cmd/alice-lg/alice-lg-linux-amd64 /usr/bin/alice-lg
# RUN ls -lsha /usr/bin/alice-lg
ADD etc/alice-lg /etc/alice-lg

EXPOSE 7340:7340

CMD ["/usr/bin/alice-lg"]