#!/usr/bin/env bash 

# global -----------------------------------------------------------------------
[[ "$TRACE" ]] && set -x
die_msg=""
die() { echo "$die_msg""$*" >&2 ; exit 1 ; }

# default env ------------------------------------------------------------------
export TARGET="UBUNTUAWS"
HOMEDIR=/home/$(id -un)/harmonie-build

# set COMPILER (ARM GNU, x86-64 GNU or Intel)
dpkg -l|grep gfortran-8 && COMPILER=GNU
dpkg -l|grep intel-oneapi-compiler-fortran && COMPILER=INTEL
if [[ x$COMPILER == xGNU ]]; then
  ls -l /usr/bin/cpp-8 && CPP=/usr/bin/cpp-8
else
  ls -l /usr/bin/cpp && CPP=/usr/bin/cpp
fi
ls /lib/cpp || sudo ln -s $CPP /lib/cpp 

# set BENCHMARKING
if [[ -z ${BENCHMARKING+x} ]]; then 
  echo "Default is to build the suite once"
  BENCHMARKING=NO
else
  BENCHMARKING=$BENCHMARKING
fi

# set BUILD_PRECISION
if [[ -z ${BUILD_PRECISION+x} ]]; then 
  echo "Default precision is double and all apps will work with this"
  BUILD_PRECISION=double
else
  BUILD_PRECISION=$BUILD_PRECISION
fi

# set MPISTACK
# (ARM:AWS-OPENMPI, x86-64+GNU:AWS-INTELMPI, x86-64+INTEL: INTELMPI)
source /usr/share/modules/init/sh
dpkg --print-architecture |grep arm64 && export MPISTACK="AWS-OPENMPI"
dpkg --print-architecture |grep amd64 && export MPISTACK="AWS-INTELMPI"
if [[ x$COMPILER == xINTEL ]]; then
  dpkg --print-architecture |grep amd64 && export MPISTACK="INTELMPI"
  source /opt/intel/bin/compilervars.sh intel64
  source /opt/intel/bin/compilervars.sh -arch intel64 -platform linux
  source /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh -arch intel64 -platform linux
  export PATH=$PATH:/opt/intel/oneapi/compiler/2021.3.0/linux/bin/intel64/
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/intel/oneapi/compiler/2021.3.0/linux/compiler/lib/intel64_lin
  MYFILE="AWS.intel.x86-64.avx2.intelmpi"
  if [[ x$BENCHMARKING == xYES ]]; then
    MYFILE="AWS.intel.x86-64.avx2-tuned.intelmpi"
  fi
fi
if [[ x$MPISTACK == xAWS-OPENMPI && x$COMPILER == xGNU ]]; then
  module load openmpi/4.1.0 # aws-parallelcluster-2.10.3-ubuntu-1804
  MYFILE="AWS.gfortran.graviton.openmpi"
fi
if [[ x$MPISTACK == xAWS-INTELMPI && x$COMPILER == xGNU ]]; then
  module load intelmpi # aws-parallelcluster, intelmpi
  MYFILE="AWS.gfortran.x86-64.intelmpi"
fi

unwrapcommon() {
  if [[ -f ./harmonie_source.tar.gz ]]; then
    tar zxf ./harmonie_source.tar.gz   
    rm -f harmonie_source/harmonie_source.tar
    mv harmonie_source harmonie_src 
    rm -f harmonie_src/util/makeup/config.linux.gfortran*
    rm -f harmonie_source.tar.gz 
  fi
}

buildme() {
  # build, env variable BUILD_CONFIG may be used to point to a specific file
  # we set default vars for ubuntu cf. header
  export TERM=dumb
  CONFIG_DIR="benchmark/build/share/"
  command -v mpicc
  command -v mpif90
  mpicc -show
  mpif90 -show
  mpirun --version
  MYCONFIG="${CONFIG_DIR}/config.$MYFILE" 
  test -f "${HOMEDIR}/${MYCONFIG}" || exit 1
  test -f "${HOMEDIR}/${MYCONFIG}" && cat "${MYCONFIG}"
  cd "${HOMEDIR}/benchmark/build" || exit 1
  echo "STARTING BUILD"
  time ./build.sh -m "$TARGET" -c "$COMPILER" -d "$HOMEDIR/harmonie_src" -i "$HOMEDIR/install" -p "$BUILD_PRECISION" -f "$MYFILE" || make fclibs
  echo "BUILD ENDED"
  rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/src"
  rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/util"
  rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/install/lib/"
  mkdir -p "/home/ubuntu/install/${MPISTACK}" || exit 1
  mv "${HOMEDIR}/install/${COMPILER}" "/home/ubuntu/install/${MPISTACK}" || exit 1
  if [[ x$COMPILER == xINTEL && x$BENCHMARKING == xYES ]]; then
    # build both avx2 and avx512 variant with intel compiler
    mkdir -p "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2"
    mv "/home/ubuntu/install/${MPISTACK}/${COMPILER}" "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2"
    MYFILE="AWS.intel.x86-64.avx2-tuned-huge.intelmpi"
    cd "${HOMEDIR}/benchmark/build" || exit 1
    echo "STARTING BUILD"
    time ./build.sh -m "$TARGET" -c "$COMPILER" -d "$HOMEDIR/harmonie_src" -i "$HOMEDIR/install" -p "$BUILD_PRECISION" -f "$MYFILE" || make fclibs
    echo "BUILD ENDED"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/src"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/util"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/install/lib/"
    mkdir -p "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2-tbb" || exit 1
    mv "${HOMEDIR}/install/${COMPILER}" "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2-tbb" || exit 1
    MYFILE="AWS.intel.x86-64.avx512.intelmpi"
    MYFILE="AWS.intel.x86-64.avx512-tuned.intelmpi"
    cd "${HOMEDIR}/benchmark/build" || exit 1
    echo "STARTING BUILD"
    time ./build.sh -m "$TARGET" -c "$COMPILER" -d "$HOMEDIR/harmonie_src" -i "$HOMEDIR/install" -p "$BUILD_PRECISION" -f "$MYFILE" || make fclibs
    echo "BUILD ENDED"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/src"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/util"
    rm -fr "${HOMEDIR}/install/${COMPILER}/${BUILD_PRECISION}/install/lib/"
    mkdir -p "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx512" || exit 1
    mv "${HOMEDIR}/install/${COMPILER}" "/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx512" || exit 1
  fi
}

main() {
  unwrapcommon
  buildme
}

main "${@}"
