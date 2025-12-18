#!/bin/bash
set -euo pipefail

# Script to update artifacts.lock.yaml with latest stable OpenShift client binaries
# and protoc binaries for all architectures
# Fetches the most recent z-stream (X.Y.Z) version for all architectures

# Version configuration
PROTOC_VERSION="${PROTOC_VERSION:-21.9}"  # Can be overridden via environment variable

MIRROR_BASE="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
OUTPUT_FILE="artifacts.lock.yaml"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Fetching OpenShift version list from $MIRROR_BASE..."

# Fetch directory listing and parse versions
VERSIONS=$(curl -sL "$MIRROR_BASE/" | \
    grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/"' | \
    sed 's/href="//g' | \
    sed 's/\/"//g' | \
    sort -V)

# Filter to only stable versions (X.Y.Z format, no -rc, -ec, -fc, etc.)
STABLE_VERSIONS=$(echo "$VERSIONS" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)

if [ -z "$STABLE_VERSIONS" ]; then
    echo "Error: No stable versions found"
    exit 1
fi

# Get the latest version
LATEST_VERSION=$(echo "$STABLE_VERSIONS" | tail -n1)
echo "Latest stable version: $LATEST_VERSION"

# Download sha256sum.txt
SHA256_URL="${MIRROR_BASE}/${LATEST_VERSION}/sha256sum.txt"
SHA256_FILE="${TEMP_DIR}/sha256sum.txt"
echo "Fetching checksums from $SHA256_URL..."
if ! curl -fsSL -o "$SHA256_FILE" "$SHA256_URL"; then
    echo "Error: Failed to download sha256sum.txt"
    exit 1
fi

# Architecture mapping: repo_arch -> openshift_arch
declare -A ARCH_MAP=(
    ["x86_64"]="amd64"
    ["aarch64"]="arm64"
    ["s390x"]="s390x"
    ["ppc64le"]="ppc64le"
)

# Start building artifacts.lock.yaml
cat > "$OUTPUT_FILE" <<EOF
metadata:
  version: '1.0'
artifacts:
EOF

# Process each architecture
for REPO_ARCH in x86_64 aarch64 s390x ppc64le; do
    OCP_ARCH="${ARCH_MAP[$REPO_ARCH]}"

    # Try rhel9-specific version first (matches current rpms.lock.yaml el9), then fall back to generic
    TARBALL="openshift-client-linux-${OCP_ARCH}-rhel9-${LATEST_VERSION}.tar.gz"
    CHECKSUM=$(grep "$TARBALL" "$SHA256_FILE" | awk '{print $1}')

    # If rhel9 version not found, try generic version
    if [ -z "$CHECKSUM" ]; then
        TARBALL="openshift-client-linux-${OCP_ARCH}-${LATEST_VERSION}.tar.gz"
        CHECKSUM=$(grep "$TARBALL" "$SHA256_FILE" | awk '{print $1}')
    fi

    if [ -z "$CHECKSUM" ]; then
        echo "Warning: Checksum not found for $REPO_ARCH, skipping..."
        continue
    fi

    URL="${MIRROR_BASE}/${LATEST_VERSION}/${TARBALL}"

    echo "Processing $REPO_ARCH ($OCP_ARCH)..."
    echo "  Tarball: $TARBALL"
    echo "  URL: $URL"
    echo "  SHA256: $CHECKSUM"

    # Append to artifacts.lock.yaml
    cat >> "$OUTPUT_FILE" <<EOF
  - download_url: $URL
    checksum: 'sha256:$CHECKSUM'
    filename: openshift-client-linux-${REPO_ARCH}.tar.gz
EOF
done

echo ""
echo "Processing protoc v${PROTOC_VERSION} artifacts..."

# Protoc architecture mapping (protoc uses different naming)
declare -A PROTOC_ARCH_MAP=(
    ["x86_64"]="x86_64"
    ["aarch64"]="aarch_64"
    ["s390x"]="s390_64"
    ["ppc64le"]="ppcle_64"
)

PROTOC_BASE_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}"

for REPO_ARCH in x86_64 aarch64 s390x ppc64le; do
    PROTOC_ARCH="${PROTOC_ARCH_MAP[$REPO_ARCH]}"
    PROTOC_ZIP="protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCH}.zip"
    PROTOC_URL="${PROTOC_BASE_URL}/${PROTOC_ZIP}"

    echo "Downloading $PROTOC_ZIP..."
    PROTOC_FILE="${TEMP_DIR}/${PROTOC_ZIP}"

    if ! curl -fsSL -o "$PROTOC_FILE" "$PROTOC_URL"; then
        echo "Error: Failed to download $PROTOC_ZIP"
        exit 1
    fi

    # Calculate SHA256
    CHECKSUM=$(sha256sum "$PROTOC_FILE" | awk '{print $1}')

    echo "  URL: $PROTOC_URL"
    echo "  SHA256: $CHECKSUM"

    # Append to artifacts.lock.yaml
    cat >> "$OUTPUT_FILE" <<EOF
  - download_url: $PROTOC_URL
    checksum: 'sha256:$CHECKSUM'
    filename: $PROTOC_ZIP
EOF
done

echo ""
echo "Successfully updated $OUTPUT_FILE with:"
echo "  - OpenShift clients: $LATEST_VERSION"
echo "  - Protoc: v$PROTOC_VERSION"
echo ""
echo "All artifacts:"
grep "download_url:" "$OUTPUT_FILE" | sed 's/.*download_url: /  - /'
