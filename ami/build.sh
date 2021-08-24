#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AMISPECDIR=""

die_msg=""
die() { echo "$die_msg""$*" >&2 ; exit 1 ; }

# ------------------------------------------------------------------------------
# TARGET is a list of all the AMI targets that one wishes to build
declare -A TARGET
#TARGET['m5.4xlarge']="aws-parallelcluster-2.10.3-ubuntu-1804-lts-hvm-x86_64-202103172101"
#TARGET['c6g.4xlarge']="aws-parallelcluster-2.10.3-ubuntu-1804-lts-hvm-arm64-202103172101"
TARGET['m5.4xlarge']="aws-parallelcluster-2.11.1-ubuntu-2004-lts-hvm-x86_64-202107212100"
declare -A OSDEP
OSDEP['production']="ubuntu-2004"
OSDEP['benchmark']="ubuntu-1804"
# ------------------------------------------------------------------------------

run_packer() {
  [[ $# -lt 2 ]] && die "Usage: run_packer instance-type ami-image"
  instance=$1
  ami=$2
  if hash packer 2>/dev/null; then
    test -f "${SCRIPT_DIR}"/"${AMISPECDIR}"/image.json || die "Missing ami specfile ${AMISPECDIR}/image.json"
    PACKER_LOG=1 packer build -var "ami_source=${ami}" -var "ami_instance=${instance}" "${SCRIPT_DIR}/${AMISPECDIR}/image.json"
  else
    echo "Packer must be installed on your system, please go to packer.io"
    exit 1
  fi
}

main() {
  [[ $# -lt 1 ]] && die "Usage: ./build.sh <ami-directory>"
  AMISPECDIR=$1
  test -d "${AMISPECDIR}" || die "No such directory ${AMISPECDIR}"
  test -f "${AMISPECDIR}"/image.json || die "Missing ami specfile ${AMISPECDIR}/image.json"
  test -d generic || die "Missing generic directory"
  cd "${SCRIPT_DIR}" || die "Failed to cd to project home"
  test -f harmonie-build.tar.gz && rm -f harmonie-build.tar.gz
  tar -czvf harmonie-build.tar.gz harmonie-build || exit
  aws s3 cp harmonie-build.tar.gz s3://bucket-aws4harmonie/
  rm -f harmonie-build.tar.gz
  for k in "${!TARGET[@]}"
  do
    if test -n "${OSDEP["$AMISPECDIR"]}";
    then
      echo "Current target: $k ${TARGET[$k]}"
      echo "Let us test if ${AMISPECDIR} dependencies are met by current target"
      echo "${TARGET[$k]}" | grep "${OSDEP["$AMISPECDIR"]}" || die "$AMISPECDIR dependencies are not met by current target, bail out"
      echo "${AMISPECDIR} dependencies are indeed met by current target, so lets build the AMI"
    fi
    run_packer $k ${TARGET[$k]}
    sleep 120
  done
}

main "${@}"
