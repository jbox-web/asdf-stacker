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

  echo "Downloading [${binary_name}] (from ${download_url} to ${download_path})"
  curl -Lo "${download_path}" "${download_url}"

  echo "Creating bin directory (${bin_install_path})"
  mkdir -p "${bin_install_path}"

  echo "Cleaning previous binaries (${binary_path})"
  rm -f "${binary_path}" 2>/dev/null || true

  echo "Copying binary"
  cp "${download_path}" "${binary_path}"
  chmod +x "${binary_path}"
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
  cmd="curl -s"

  if [ -n "${GITHUB_API_TOKEN:-}" ]; then
    cmd="${cmd} -H 'Authorization: token ${GITHUB_API_TOKEN}'"
  fi

  cmd="${cmd} ${releases_path}"

  # Fetch all tag names, and get only second column. Then remove all unnecesary characters.
  versions=$(eval ${cmd} | grep -oE "tag_name\": *\".{1,15}\"," | sed 's/tag_name\": *\"v//;s/\",//' | sort_versions)
  echo "${versions}"
}
