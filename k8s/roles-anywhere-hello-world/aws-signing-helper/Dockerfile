FROM amazonlinux:2023

ARG AWS_SIGNING_HELPER_VERSION=1.8.0
ARG TARGETARCH

RUN dnf install -y shadow-utils \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN case "${TARGETARCH}" in \
      ""|"amd64") helper_arch="X86_64" ;; \
      "arm64") helper_arch="Aarch64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://rolesanywhere.amazonaws.com/releases/${AWS_SIGNING_HELPER_VERSION}/${helper_arch}/Linux/Amzn2023/aws_signing_helper" -o /usr/local/bin/aws_signing_helper \
    && chmod 0755 /usr/local/bin/aws_signing_helper \
    && useradd --create-home --uid 10001 helper

USER 10001

ENTRYPOINT ["/usr/local/bin/aws_signing_helper"]
