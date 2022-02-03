#!/bin/bash

# template from https://betterdev.blog/minimal-safe-bash-script-template/
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-nc] [-s] [-tr RUNTIME] [-tv VERSION] [-p PLATFORM] [-a ARCH] [-pt EXTRA]

Generates prebuilds using prebuildify.
If prebuildify is missing, install it:
  npm install -g prebuildify
  
NOTE: mklove (used by librdkafka) does not support cross-compiling.
      Setting arch and platform will likely do nothing.

Available options:

-h,   --help                      Print this help and exit
      --install-recommended       Install recommended build-tools for librdkafka (Linux only)
-v,   --verbose                   Print script debug info
-nc,  --no-color                  Disable colors
-s,   --strip                     Strip symbols from the build result
-tr,  --target-runtime[=node]     Target 'node' or 'electron'
-tv,  --target-version[=16.13.2]  Target Node/Electron version
-p,   --platform[=detect]         Target platform (e.g., 'darwin', 'linux', 'win32')
-a,   --arch[=detect]             Target architecture (e.g., 'x64', 'ia32', 'x32')
-pt,  --passthrough               Args to pass directly to Prebuildify.
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

do_install_recommended_linux() {
msg "${ORANGE}Installing recommended packages (Linux only)${NOFORMAT}\n"

apt-get install g++ openssl libcurl4-openssl-dev \
  make python3 make libsasl2-dev \
  liblz4-dev rapidjson-dev libzstd-dev libssl-dev -y
  
die "\n${ORANGE}Done.${NOFORMAT}" 0
}

parse_params() {
EMPTY_PASS="<empty>"
EMPTY_PLATFORM_ARCH="detect"
STRIP_FLAG="--strip"

  # default values of variables set from params
  strip=false
  runtime='node'
  version='16.13.2'
  platform=$EMPTY_PLATFORM_ARCH
  arch=$EMPTY_PLATFORM_ARCH
  passthrough=$EMPTY_PASS

  while :; do
    case "${1-}" in
    "-?" | -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -nc | --no-color) NO_COLOR=1 ;;
    --install-recommended) do_install_recommended_linux ;;
    -s | --strip) strip=true ;;
    -tr | --target-runtime)
      runtime="${2-}"
      shift
      ;;
    -tv | --target-version)
      version="${2-}"
      shift
      ;;
    -p | --platform)
      platform="${2-}"
      shift
      ;;
    -a | --arch)
      arch="${2-}"
      shift
      ;;
    -pt | --passthrough)
      passthrough="${2-}"
      shift
      while [[ -n "${2-}" ]]; do
        passthrough="$passthrough ${2-}"
        shift
      done
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  return 0
}

validate_params() {
  case "$arch" in
    $EMPTY_PLATFORM_ARCH) ;;
    "arm") ;;
    "arm64") ;;
    "ia32") ;;
    "mips") ;;
    "mipsel") ;;
    "ppc") ;;
    "ppc64") ;;
    "s390") ;;
    "s390x") ;;
    "x32") ;;
    "x64") ;;
  *) die "Invalid arch: $arch" ;;
  esac
  
case "$platform" in
    $EMPTY_PLATFORM_ARCH) ;;
    'aix') ;;
    'darwin') ;;
    'freebsd') ;;
    'linux') ;;
    'openbsd') ;;
    'sunos') ;;
    'win32') ;;
  *) die "Invalid platform: $platform" ;;
  esac
  
case "$runtime" in
    'node') ;;
    'electron') ;;
  *) die "Invalid runtime: $runtime" ;;
  esac
}

setup_colors
parse_params "$@"
validate_params

type -P prebuildify &>/dev/null || (msg "${RED}Prebuildify not found. It can be installed with:${NOFORMAT}" && die "  npm install -g prebuildify\n")

msg "${CYAN}Building with options:${NOFORMAT}"
msg "- strip: ${strip}"
msg "- runtime: ${runtime}"
msg "- version: ${version}"
msg "- platform: ${platform}"
msg "- arch: ${arch}"
msg "- passthrough: ${passthrough}\n"

if [[ $passthrough == $EMPTY_PASS ]]; then
  passthrough=''
fi

if [[ $arch == $EMPTY_PLATFORM_ARCH ]]; then
  arch=''
fi

if [[ $platform == $EMPTY_PLATFORM_ARCH ]]; then
  platform=''
fi

if [[ $strip == true ]]; then
  if [[ -n $passthrough ]]; then
    passthrough=" $STRIP_FLAG $passthrough"
  else
    passthrough=" $STRIP_FLAG"
  fi
fi

if [[ -n $arch ]]; then
    arch=" --arch $arch"
fi

if [[ -n $platform ]]; then
    platform=" --platform $platform"
fi

restore_flag=0
flag_before=''

if [[ -n ${BUILD_LIBRDKAFKA-} ]]; then
  restore_flag=1
  flag_before=$BUILD_LIBRDKAFKA
  unset BUILD_LIBRDKAFKA
  msg "${RED}Unsetting BUILD_LIBRDKAFKA flag for build${NOFORMAT}\n"
fi

TO_EXECUTE="prebuildify -t $runtime@$version$platform$arch$passthrough"

msg "Do: ${CYAN}$TO_EXECUTE${NOFORMAT}\n"

eval $TO_EXECUTE

if [[ $restore_flag == 1 ]]; then
  export BUILD_LIBRDKAFKA=$flag_before
  msg "${GREEN}Restored BUILD_LIBRDKAFKA=$flag_before${NOFORMAT}\n"
fi
