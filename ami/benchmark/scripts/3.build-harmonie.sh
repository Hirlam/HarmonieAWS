#!/usr/bin/env bash

prepare() {
  cd "${HOME}" || exit 1
  aws s3 cp s3://bucket-aws4harmonie/aws4harm.tar.gz .
  tar -zxvf aws4harm.tar.gz
  cd "${HOME}"/aws4harm || exit 1
}

build_harmonie() {
  aws s3 cp s3://bucket-aws4harmonie/harmonie_source.tar.gz .
  ./reproduce.sh 
  rm -fr harmonie_source 
  rm -fr harmonie_src
}

get_tiny_testcase() {
  cd /home/ubuntu/ || exit 1
  aws s3 cp s3://bucket-harmonie-src/input_data_TINY.tar.gz .
  tar -zxvf input_data_TINY.tar.gz
  test -f input_data_TINY.tar.gz && rm -f input_data_TINY.tar.gz 
}

cleanup() {
  ls aws4harm/harmonie_source.tar.gz && rm -f aws4harm/harmonie_source.tar.gz
  test -f aws4harm.tar.gz && rm -f aws4harm.tar.gz
  test -f aws4harm/reproduce.sh && rm -f aws4harm/reproduce.sh
}

documentation() {
  cd "${HOME}" || exit 1
  cat << END > README.txt
# TLDR
$ git clone git@github.com/Hirlam/HarmonieAWS
$ cd HarmonieAWS/benchmark
$ ./runfc.sh
END
}


main() {
  prepare
  export BUILD_PRECISION=single
  # export BENCHMARKING="YES" # build multiple versions (different MPI stacks and FLAGS of the binaries)
  build_harmonie
  #export BUILD_PRECISION=double # we need this for all binaries but the forecast
  #build_harmonie
  get_tiny_testcase
  cleanup
  documentation
}

main "${@}"

