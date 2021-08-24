#!/usr/bin/env bash

set +x

prepare() {
  cd "${HOME}" || exit 1
  aws s3 cp s3://bucket-aws4harmonie/harmonie-build.tar.gz .
  tar -zxvf harmonie-build.tar.gz
}

build_harmonie() {
  cd "${HOME}"/harmonie-build || exit 1
  aws s3 cp s3://bucket-aws4harmonie/harmonie_source_dmi.tar.gz ./harmonie_source.tar.gz 
  ./reproduce.sh 
}

cleanup() {
  test -f "${HOME}"/harmonie-build.tar.gz && rm -f "${HOME}"/harmonie-build.tar.gz
  test -d "${HOME}"/harmonie-build && rm -fr "${HOME}"/harmonie-build
}

documentation() {
  cd "${HOME}" || exit 1
  cat << END > README.txt
# TLDR

#a. Fill the attached Lustre directory with testcase data:
ubuntu@ip-172-31-15-45:~$ mkdir -p /shared/ubuntu/
ubuntu@ip-172-31-15-45:~$ cd /shared/ubuntu/
ubuntu@ip-172-31-15-45:/shared/ubuntu$ aws s3 cp s3://bucket-aws4harmonie/nea43input.tar.gz .
ubuntu@ip-172-31-15-45:/shared/ubuntu$ tar -zxvf nea43input.tar.gz
ubuntu@ip-172-31-15-45:/shared/ubuntu$ rm -f nea43input.tar.gz

#b. clone (cloud repo) or upload clone (on-prem repo) of POC branch - use S3 from ec2host or scp from on prem host:

#b1 - variant1: on-prem repo
ssh -i cert.pem -X ubuntu@<ec2host>
mkdir check-out && cd check-out
aws s3 cp s3://bucket-aws4harmonie/nea43.tar.gz .
tar -zxvf nea43.tar.gz

#b2 - variant2: cloud repository
ssh -i cert.pem -X ubuntu@<ec2host>
mkdir check-out && cd check-out
git clone <branchname> https://github.com/Hirlam/Harmonie nea43

#c. Run the full cycle using the Launch helper script:
ssh -i cert.pem -X ubuntu@<ec2host>
ecflow_start 
cd check-out/nea43
rm -f Env_submit Env_system config-sh/hm_rev # better safe than sorry
./config-sh/Harmonie setup -r $(pwd) -h AWS.NEA-intel
export RELAUNCH=yes; sh Launch
END
}

main() {
  prepare
  export BUILD_PRECISION=single # this is for the forecast
  build_harmonie
  cleanup
  prepare
  export BUILD_PRECISION=double # we need this for all binaries but the forecast
  build_harmonie
  cleanup
  documentation
}

main "${@}"

