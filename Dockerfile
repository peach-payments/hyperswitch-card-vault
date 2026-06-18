FROM rust:slim-trixie AS builder

WORKDIR /locker

ENV CARGO_NET_RETRY=10
ENV RUSTUP_MAX_RETRIES=10
ENV CARGO_INCREMENTAL=0

# Build argument to determine which features to use
ARG DEV=false

RUN apt-get update \
    && apt-get install -y libpq-dev libssl-dev pkg-config

COPY . .
# Use a conditional to set the features flag based on DEV value
RUN if [ "$DEV" = "true" ]; then \
        echo "Building with dev features"; \
        cargo build --release --features dev ${EXTRA_FEATURES}; \
    else \
        echo "Building with release features"; \
        cargo build --release --features release ${EXTRA_FEATURES}; \
    fi


FROM debian:trixie-slim

ARG CONFIG_DIR=/local/config
ARG BIN_DIR=/local
ARG BINARY=locker

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y ca-certificates tzdata libpq-dev curl procps \
    # CVE-2026-12087: the base image's perl-base bundles a vulnerable Socket
    # module (Socket.pm < 2.041 — heap over-read in pack_ip_mreq_source), and
    # Debian has not yet published a patched perl. The locker and utils
    # binaries are Rust and never invoke Perl, so remove it from the runtime
    # image entirely to drop the vulnerable code path.
    && apt-get purge -y --allow-remove-essential perl-base \
    && apt-get autoremove -y --purge \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8080

RUN mkdir -p ${CONFIG_DIR}

COPY --from=builder /locker/target/release/${BINARY} ${BIN_DIR}/${BINARY}
COPY --from=builder /locker/target/release/utils ${BIN_DIR}/utils

WORKDIR ${BIN_DIR}

CMD ["./locker"]

