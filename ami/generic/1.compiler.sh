#!/usr/bin/env bash

common() {
  set -o errexit
  set -o pipefail
  sudo DEBIAN_FRONTEND=noninteractive apt-get update --fix-missing 
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -q \
    bash \
    bison \
    cmake \
    file \
    flex \
    ksh \
    libblas-dev \
    liblapack-dev \
    make \
    m4 \
    perl \
    ssh \
    zlib1g-dev
}

gnu1804() {
  # note that ubuntu18.04 comes with GNU 7.5 as default compiler (and hence all libs with
  # Fortran interfaces are bound to GNU 7.5 and has to be rebuild. The cycle of Harmonie
  # source (43) that we looked at does not build with GNU 7.5 but with 8.x and 9.x so instead
  # of doing upstream source code changes, we simply upgraded the compiler (and external libs) 
  # in the AMI
  set -o nounset
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -q \
    g++-8 \
    gcc-8 \
    gfortran-8 
  ls /usr/bin/gcc-8 && sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8
  ls /usr/bin/cpp-8 && sudo update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-8 800 
  ls /usr/bin/gfortran-8 && sudo update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-8 800 
  ls /usr/bin/gfortran-8 || exit 1
}

intel() {
  # intel oneapi
  cd /tmp
  wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
  sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
  rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
  echo "deb https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
  sudo add-apt-repository "deb https://apt.repos.intel.com/oneapi all main"
  sudo DEBIAN_FRONTEND=noninteractive apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y -q \
    intel-basekit \
    intel-hpckit \
    intel-oneapi-mkl \
    intel-oneapi-runtime-mkl-common \
    intel-oneapi-runtime-mkl-common
}

main() {
  common
#  gnu1804
  intel
}

main "${@}"
# ------------------------------------------------------------------------------
	
