FROM golang:1.22.2-alpine3.19@sha256:cdc86d9f363e8786845bea2040312b4efa321b828acdeb26f393faa864d887b0 AS build

WORKDIR /go/src/github.com/osrg/gobgp/

ARG BUILD_VERSION
ARG ARCHIVE_URL=https://github.com/osrg/gobgp/archive/

ENV CGO_ENABLED 0

RUN test -n "${BUILD_VERSION}" \
	&& apk update \
	&& apk upgrade -a \
	&& apk add --no-cache ca-certificates curl gcc musl-dev \
	&& update-ca-certificates \
	&& curl -L "${ARCHIVE_URL}/${BUILD_VERSION}.tar.gz" -o /tmp/gobgp.tar.gz \
	&& tar xzf /tmp/gobgp.tar.gz --strip 1 -C /go/src/github.com/osrg/gobgp \
	&& go get -u golang.org/x/net \
	&& go mod tidy \
	&& go build -v -trimpath -ldflags="-s -w" ./cmd/gobgp/ \
	&& go build -v -trimpath -ldflags="-s -w" ./cmd/gobgpd/ 

WORKDIR /config

# ----------------------------------------------------------------------------

FROM golang:1.22.2-alpine3.19@sha256:cdc86d9f363e8786845bea2040312b4efa321b828acdeb26f393faa864d887b0 AS entrypoint-build

ENV CGO_ENABLED 0

ADD gobgpEntrypoint /go/src/github.com/wrgeorge1983/alice-deploy/gobgpEntrypoint/

WORKDIR /go/src/github.com/wrgeorge1983/alice-deploy/gobgpEntrypoint/
RUN pwd 
RUN ls -alh
RUN go mod tidy \
	&& go build -v -trimpath -ldflags="-s -w" -o /gobgpEntrypoint .

# ----------------------------------------------------------------------------


FROM scratch

LABEL org.opencontainers.image.authors="Jauder Ho <jauderho@users.noreply.github.com>"
LABEL org.opencontainers.image.url="https://github.com/jauderho/dockerfiles"
LABEL org.opencontainers.image.documentation="https://github.com/jauderho/dockerfiles"
LABEL org.opencontainers.image.source="https://github.com/jauderho/dockerfiles"
LABEL org.opencontainers.image.title="jauderho/gobgp"
LABEL org.opencontainers.image.description="GoBGP is an open source BGP implementation"

COPY --from=build /etc/passwd /etc/group /etc/
COPY --from=build /etc/ssl/certs /etc/ssl/certs

COPY --from=build /go/src/github.com/osrg/gobgp/gobgp /usr/local/bin/
COPY --from=build /go/src/github.com/osrg/gobgp/gobgpd /usr/local/bin/
COPY --from=build --chown=nobody:nogroup /config /config

COPY --from=entrypoint-build /gobgpEntrypoint /usr/local/bin/
COPY --from=entrypoint-build  --chown=nobody:nobody /go/src/github.com/wrgeorge1983/alice-deploy/gobgpEntrypoint/gobgpd_empty.yml /config/

EXPOSE 179
USER nobody

#ENTRYPOINT ["/usr/local/bin/gobgpd"]
#CMD ["-f", "/config/gobgp.toml"]
CMD ["/usr/local/bin/gobgpEntrypoint"]