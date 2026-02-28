#!/bin/sh
# install.sh — curl-pipe-bash installer for clawpass
# Usage: curl -fsSL https://raw.githubusercontent.com/christmas-island/clawpass/main/install.sh | sh
set -eu

REPO="christmas-island/clawpass"
BINARY="clawpass"
INSTALL_DIR="${CLAWPASS_INSTALL_DIR:-}"

info()  { printf '[clawpass] %s\n' "$*" >&2; }
error() { printf '[clawpass] ERROR: %s\n' "$*" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) error "Unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) error "Unsupported architecture: $(uname -m)" ;;
  esac
}

get_target() {
  local os="$1" arch="$2"
  case "${os}-${arch}" in
    linux-x86_64)   echo "x86_64-unknown-linux-musl" ;;
    linux-aarch64)  echo "aarch64-unknown-linux-musl" ;;
    macos-x86_64)   echo "x86_64-apple-darwin" ;;
    macos-aarch64)  echo "aarch64-apple-darwin" ;;
    windows-x86_64) echo "x86_64-pc-windows-msvc" ;;
    *) error "No prebuilt binary for ${os} ${arch}" ;;
  esac
}

get_latest_version() {
  local url="https://api.github.com/repos/${REPO}/releases/latest"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
  else
    error "Neither curl nor wget found. Install one and retry."
  fi
}

download() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  fi
}

verify_checksum() {
  local file="$1" expected="$2"
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | cut -d' ' -f1)
  else
    info "Warning: no sha256sum or shasum found, skipping checksum verification"
    return 0
  fi

  if [ "$actual" != "$expected" ]; then
    error "Checksum mismatch!\n  expected: ${expected}\n  got:      ${actual}"
  fi
  info "Checksum verified."
}

resolve_install_dir() {
  if [ -n "$INSTALL_DIR" ]; then
    echo "$INSTALL_DIR"
    return
  fi

  local home_bin="$HOME/.local/bin"
  if [ -d "$home_bin" ] && [ -w "$home_bin" ]; then
    echo "$home_bin"
  elif [ -w "/usr/local/bin" ]; then
    echo "/usr/local/bin"
  else
    echo "$home_bin"
  fi
}

main() {
  info "Installing ${BINARY}..."

  local os arch target version
  os=$(detect_os)
  arch=$(detect_arch)
  target=$(get_target "$os" "$arch")
  info "Detected platform: ${os} ${arch} (${target})"

  version="${CLAWPASS_VERSION:-$(get_latest_version)}"
  if [ -z "$version" ]; then
    error "Could not determine latest version. Set CLAWPASS_VERSION to install a specific version."
  fi
  info "Version: ${version}"

  local ext="tar.gz"
  if [ "$os" = "windows" ]; then
    ext="zip"
  fi

  local archive="${BINARY}-${version}-${target}.${ext}"
  local checksum_file="${BINARY}-${version}-${target}.${ext}.sha256"
  local base_url="https://github.com/${REPO}/releases/download/${version}"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  info "Downloading ${archive}..."
  download "${base_url}/${archive}" "${tmpdir}/${archive}"

  info "Downloading checksum..."
  download "${base_url}/${checksum_file}" "${tmpdir}/${checksum_file}"

  local expected_checksum
  expected_checksum=$(cut -d' ' -f1 < "${tmpdir}/${checksum_file}")
  verify_checksum "${tmpdir}/${archive}" "$expected_checksum"

  info "Extracting..."
  if [ "$ext" = "zip" ]; then
    unzip -qo "${tmpdir}/${archive}" -d "${tmpdir}/out"
  else
    mkdir -p "${tmpdir}/out"
    tar xzf "${tmpdir}/${archive}" -C "${tmpdir}/out"
  fi

  local bin_name="$BINARY"
  if [ "$os" = "windows" ]; then
    bin_name="${BINARY}.exe"
  fi

  local install_dir
  install_dir=$(resolve_install_dir)
  mkdir -p "$install_dir"

  local src="${tmpdir}/out/${bin_name}"
  if [ ! -f "$src" ]; then
    # Some archives nest inside a directory
    src=$(find "${tmpdir}/out" -name "$bin_name" -type f | head -1)
    if [ -z "$src" ]; then
      error "Binary not found in archive"
    fi
  fi

  if [ -w "$install_dir" ]; then
    cp "$src" "${install_dir}/${bin_name}"
    chmod +x "${install_dir}/${bin_name}"
  else
    info "Elevated permissions required to install to ${install_dir}"
    sudo cp "$src" "${install_dir}/${bin_name}"
    sudo chmod +x "${install_dir}/${bin_name}"
  fi

  info "Installed ${bin_name} to ${install_dir}/${bin_name}"

  # Check if install_dir is in PATH
  case ":${PATH}:" in
    *":${install_dir}:"*) ;;
    *)
      info ""
      info "Add ${install_dir} to your PATH:"
      info "  export PATH=\"${install_dir}:\$PATH\""
      info ""
      ;;
  esac

  info "Done! Run '${BINARY} --help' to get started."
}

main "$@"
