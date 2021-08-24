#!/usr/bin/env bash

install_hdf5() {
  # build hdf5 with fortran support 
  mkdir -p "$PREFIX"
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit 1
  aws s3 cp s3://bucket-aws4harmonie/hdf5-1.12.0.tar.gz .
  tar -xzf ./hdf5-1.12.0.tar.gz
  mkdir build
  cd build || exit
  "$PREFIX"/cmake/bin/cmake  ../hdf5-1.12.0 -DCMAKE_INSTALL_PREFIX="$PREFIX"/hdf5 -DHDF5_ENABLE_Z_LIB_SUPPORT:BOOL=ON -DHDF5_BUILD_FORTRAN:BOOL=ON 
  make -j || exit 1
  make install || exit
}

install_netcdf_fortran() {
  # netcdf-fortran
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit
  aws s3 cp s3://bucket-aws4harmonie/netcdf-fortran-4.5.3.tar.gz .
  tar -zxf ./netcdf-fortran-4.5.3.tar.gz
  cd netcdf-fortran-4.5.3 || exit 1
  export LDFLAGS="-L$PREFIX/netcdf/lib -lnetcdf"
  CFLAGS="-I$PREFIX/netcdf/include -I$PREFIX/hdf5/include" CPPFLAGS="-I$PREFIX/netcdf/include -I$PREFIX/hdf5/include" LDFLAGS="-L$PREFIX/hdf5/lib -L$PREFIX/netcdf/lib -lnetcdf -lhdf5 -lhdf5_hl" ./configure --prefix="$PREFIX"/netcdf  --host=x86_64 
  make -j || exit 1
  make install || exit 1
}

install_netcdf() {
  # netcdf-base
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit
  aws s3 cp s3://bucket-aws4harmonie/netcdf-c-4.7.4.tar.gz . 
  tar -zxf ./netcdf-c-4.7.4.tar.gz
  cd netcdf-c-4.7.4 || exit 1
  CFLAGS=-I"$PREFIX"/hdf5/include CPPFLAGS=-I"$PREFIX"/hdf5/include LDFLAGS=-L"$PREFIX"/hdf5/lib ./configure --disable-dap --prefix="$PREFIX"/netcdf
  make -j || exit 1
  make install || exit 1
  install_netcdf_fortran
}

install_eccodes() {
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit
  aws s3 cp s3://bucket-aws4harmonie/eccodes-2.17.0-Source.tar.gz .
  tar -xzf "./eccodes-2.17.0-Source.tar.gz"
  mkdir build
  cd build || exit
  export LD_LIBRARY_PATH="$PREFIX/hdf5/lib:$PREFIX/netcdf/lib"
  cmake  ../eccodes-2.17.0-Source -DCMAKE_INSTALL_PREFIX="$PREFIX"/eccodes
  make -j || exit 1
  make install 
}    

install_cmake() {
  # build newer version of cmake 
  mkdir -p "$PREFIX"
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit
  aws s3 cp s3://bucket-aws4harmonie/cmake-3.17.3.tar.gz . 
  test -f "cmake-3.17.3.tar.gz" && tar -xzf "cmake-3.17.3.tar.gz"
  cd cmake-3.17.3 || exit 1
  cmake . -DCMAKE_INSTALL_PREFIX="$PREFIX"/cmake -DCMAKE_USE_OPENSSL=OFF
  make -j
  make install
}

install_awscli() {
  CURL_AWS="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  dpkg --print-architecture |grep arm64 && CURL_AWS="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
  myproj=$(mktemp -d)
  mkdir -p "$myproj" || exit
  cd "$myproj" || exit
  curl "$CURL_AWS" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
}

# ------------------------------------------------------------------------------
gnu() {
  COMPILER_BRAND=GNU
  HOMEDIR=/home/$(id -un)
  PREFIX="$HOMEDIR/harmonie/${COMPILER_BRAND}"
  export CXX=g++-8
  export CC=gcc-8
  export FC=gfortran-8
  export F77=gfortran-8
  export CPP=cpp-8

  install_awscli
  install_cmake
  install_hdf5
  install_netcdf
  install_netcdf_fortran
  install_eccodes
}

# ------------------------------------------------------------------------------
intel() {
  COMPILER_BRAND=INTEL
  HOMEDIR=/home/$(id -un)
  PREFIX="$HOMEDIR/harmonie/${COMPILER_BRAND}"
  source /usr/share/modules/init/sh
  source /opt/intel/bin/compilervars.sh intel64
  export PATH=$PATH:/opt/intel/oneapi/compiler/2021.3.0/linux/bin/intel64/
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/intel/oneapi/compiler/2021.3.0/linux/compiler/lib/intel64_lin

  install_awscli
  install_cmake

  export CXX=icc
  export CC=icc
  export FC=ifort
  export F77=ifort
  export CPP=cpp

  command -v mpicc
  command -v mpiifort
  mpiicc -v
  mpiifort -v
  ifort -v
  icc -v
  install_hdf5
  install_netcdf
  install_netcdf_fortran
  install_eccodes
}

# ------------------------------------------------------------------------------
main() {
  if [[ $(dpkg -l|grep intel-oneapi-compiler-fortran) ]]; then
    intel "${@}"
  fi
  if [[ $(dpkg -l|grep gfortran-8) ]]; then
    gnu "${@}"
  fi
}

main "${@}"
# ------------------------------------------------------------------------------

