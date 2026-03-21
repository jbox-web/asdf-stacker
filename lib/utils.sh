#!/usr/bin/env bash

TOOL_NAME="stacker"
GITHUB_COORDINATES="jbox-web/${TOOL_NAME}"

function install_tool() {
  local version=${2}
  local install_path=${3}
  local tmp_download_dir=${4}
  local binary_name=${5}

  local bin_install_path="${install_path}/bin"
  local binary_path="${bin_install_path}/${binary_name}"

  local platform
  local architecture
  local download_url
  local download_path

  platform="$(get_platform)"
  architecture="$(get_architecture)"
  filename=$(get_filename "${version}" "${platform}" "${architecture}" "${binary_name}")

  download_url=$(get_download_url "${version}" "${platform}" "${architecture}" "${binary_name}")
  download_path="${tmp_download_dir}/${filename}"

  checksum_url=$(get_checksum_url "${version}" "${platform}" "${architecture}" "${binary_name}")
  checksum_path="${tmp_download_dir}/${filename}.sha256"

  log "Downloading binary (from ${download_url} to ${download_path})"
  download_file "${download_path}" "${download_url}"

  log "Downloading checksum (from ${checksum_url} to ${checksum_path})"
  download_file "${checksum_path}" "${checksum_url}"

  log "Validating binary"
  pushd "${tmp_download_dir}" >/dev/null 2>&1 || exit 1
  sha256sum --check --quiet "${checksum_path}"
  popd >/dev/null 2>&1 || exit 1

  log "Creating bin directory (${bin_install_path})"
  mkdir -p "${bin_install_path}"

  log "Cleaning previous binaries (${binary_path})"
  rm -f "${binary_path}"

  log "Copying binary (from ${download_path} to ${binary_path})"
  cp "${download_path}" "${binary_path}"
  chmod +x "${binary_path}"
}

function download_file() {
  local path
  path="${1}"

  local url
  url="${2}"

  curl --silent --show-error --location --output "${path}" "${url}"
}

function get_filename() {
  local version="${1}"
  local platform="${2}"
  local architecture="${3}"
  local binary_name="${4}"

  echo "${binary_name}-${platform}-${architecture}"
}

function get_download_url() {
  local version="${1}"
  local platform="${2}"
  local architecture="${3}"
  local binary_name="${4}"

  local filename
  filename="$(get_filename "${version}" "${platform}" "${architecture}" "${binary_name}")"

  echo "https://github.com/${GITHUB_COORDINATES}/releases/download/v${version}/${filename}"
}

function get_checksum_url() {
  local version="${1}"
  local platform="${2}"
  local architecture="${3}"
  local binary_name="${4}"

  local filename
  filename="$(get_filename "${version}" "${platform}" "${architecture}" "${binary_name}")"

  echo "https://github.com/${GITHUB_COORDINATES}/releases/download/v${version}/${filename}.sha256"
}

function get_platform() {
  local platform

  case "${OSTYPE}" in
    darwin*) platform="darwin" ;;
    linux*)  platform="linux" ;;
    *) fail "Unsupported platform" ;;
  esac

  echo "${platform}"
}

function get_architecture() {
  local architecture
  architecture="$(uname -m)"

  case "${architecture}" in
    x86_64)  architecture="amd64" ;;
    aarch64) architecture="arm64" ;;
    arm64)   architecture="arm64" ;;
    *) fail "Unsupported architecture" ;;
  esac

  echo "${architecture}"
}

# stolen from https://github.com/rbenv/ruby-build/pull/631/files#diff-fdcfb8a18714b33b07529b7d02b54f1dR942
function sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' | \
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

function list_all_versions() {
  local releases_path
  releases_path="https://api.github.com/repos/${GITHUB_COORDINATES}/releases"

  local cmd
  cmd="curl"

  local args
  args=( --silent )

  if [ -n "${GITHUB_API_TOKEN:-}" ]; then
    args+=( -H "Authorization: token ${GITHUB_API_TOKEN}" )
  fi

  args+=( "${releases_path}" )

  # Fetch all tag names, and get only second column. Then remove all unnecesary characters.
  versions=$(${cmd} "${args[@]}" | grep -oE "tag_name\": *\".{1,15}\"," | sed 's/tag_name\": *\"v//;s/\",//' | sort_versions)
  echo "${versions}"
}

function log() {
  local message="${1}"
  echo "[$(white "${binary_name}")] $(green "${message}")"
}

function print_in_color() {
  local color="$1"
  shift
  if [[ "${NO_COLOR:-}" == "" ]]; then
    printf "$color%b\e[0m\n" "$*"
  else
    printf "%b\n" "$*"
  fi
}

function green() { print_in_color "\e[32m" "$*"; }
function white() { print_in_color "\e[37m" "$*"; }
