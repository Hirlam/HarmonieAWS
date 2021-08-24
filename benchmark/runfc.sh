#!/bin/bash 

# default env ------------------------------------------------------------------
REPEAT=1
REPEAT_WITHIN_JOB=5

# COMPILER and MPI-STACK
dpkg -l|grep gfortran-8 && COMPILER=GNU
dpkg -l|grep intel-oneapi-compiler-fortran && COMPILER=INTEL
dpkg --print-architecture |grep arm64 && export MPISTACK="AWS-OPENMPI"
dpkg --print-architecture |grep amd64 && export MPISTACK="AWS-INTELMPI"
if [[ x$COMPILER == xINTEL ]]; then
  dpkg --print-architecture |grep amd64 && export MPISTACK="INTELMPI"
fi

# -------------------  SPECIFY TESTCASE HERE -----------------------------------
#TESTCASE=HUGE|MIDI|TINY
TESTCASE=HUGE
TESTCASE=TINY

# -------------------  SPECIFY DECOMPOSITION HERE ------------------------------
# 19*20=380 cores ~ 11 nodes
iHUGE=24
jHUGE=24
# 32*32= cores ~ 29 nodes
iHUGE=32
jHUGE=32
# 52*53=2756 cores ~ 77 nodes
iHUGE=52
jHUGE=53
# 55*56=3080 cores ~ 86 nodes
iHUGE=55
jHUGE=56
iHUGE=36
jHUGE=41
iHUGE=19
jHUGE=20
#iHUGE=48
#jHUGE=48
iTINY=2
jTINY=2

# -------------------  SPECIFY MPI STACK HERE ----------------------------------
PARTITION="od-queue1" # od-queue1 for C5
PARTITION="od-queue"  # od-queue for C5n or C6G

#BUILD_PRECISION=double|single
#BUILD_PRECISION=double
BUILD_PRECISION=single

#NAMIOHUGE=NOIO|IO
#NAMIOHUGE=NOIO
NAMIOHUGE=IO
EXTRA=$BUILD_PRECISION.$NAMIOHUGE.$PARTITION

TESTDIR=/shared # NFS
TESTDIR=/fsx    # Lustre
TESTDIR=/home/ubuntu/input_data_TINY
TARGET=AWS
WRKPREFIX="/shared/bmForecast"
WRK="/shared/bmForecast.$EXTRA"
# default env ------------------------------------------------------------------

cleanrun() {
  rm -f ${WRKPREFIX}.*/wrkForecast_*/PF*00*
  rm -f ${WRKPREFIX}.*/wrkForecast_*/IC*00*
}

lustreprobe() {
  lfs df -h /fsx
  if test x${TESTCASE} == xHUGE; then
    lfs getstripe /fsx/inputFcast/HUGE/ELSCFHARMALBC000
    lfs getstripe /fsx/inputFcast/HUGE/ELSCFHARMALBC001
    lfs getstripe /fsx/inputFcast/HUGE/ICMSHHARMINIT.sfx
    lfs getstripe /fsx/inputFcast/HUGE/ICMSHHARMINIT
  fi
}

runtestfc() {
  if [[ -d /fsx ]]; then
    lfs df /fsx/ && WRK="/fsx/bmForecast.$EXTRA"
    lfs df /fsx/ && lustreprobe
  fi
  for s in 0 # 4 # 8 12 14 16
  do
    echo "Running from $WRK"
    if test x${TESTCASE} == xHUGE; then
      cp ./benchmark/forecast/namelists/namelist_forecast_HUGE.$NAMIOHUGE ./benchmark/forecast/namelists/namelist_forecast_HUGE
      grep -A3 NHISTS ./benchmark/forecast/namelists/namelist_forecast_HUGE
    fi
    for t in 4 # 1
    do
      cd ./benchmark/forecast && time ./runForecast.sh -m "$TARGET" -x "$i" -y "$j" -s "$s" -t "$t" -d "$TESTCASE" -l 1 -b "$INSTALLDIR" -i "$TESTDIR" -o "$WRK" -p "$PARTITION" -r "$REPEAT_WITHIN_JOB"
    done
    sleep 30 # better safe than sorry
    cd ~/HarmonieAWS/benchmark || exit 1
  done
}


# main -------------------------------------------------------------------------
INSTALLDIR="/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx512/${COMPILER}/${BUILD_PRECISION}/install/bin/"
INSTALLDIR="/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2/${COMPILER}/${BUILD_PRECISION}/install/bin/"
INSTALLDIR="/home/ubuntu/install/${MPISTACK}/${COMPILER}/avx2-tbb/${COMPILER}/${BUILD_PRECISION}/install/bin/"
if ! test -f "${INSTALLDIR}/MASTERODB"; then
  echo "Missing the binary $INSTALLDIR/MASTERODB - bailing out"
  exit 1
fi
activejobs=$(squeue |wc -l)
if test x"$activejobs" != x1; then
  echo "Jobs running already - not a goot time for cleanup, bailing out"
  exit
else
  echo "cleanup time - get rid of binary output before running again"
  cleanrun
fi

n=1
echo "Will launch $REPEAT jobs and each job will run the code $REPEAT_WITHIN_JOB times before it stops, please ensure that walltime allows for it :))"
while [ $n -le $REPEAT ]
do
  cd ~/HarmonieAWS/benchmark || exit 1
  echo "Launching step $n"
  n=$(( n+1 ))
  if test x${TESTCASE} == xHUGE; then
    i="$iHUGE"
    j="$jHUGE"
  else
    i="$iTINY"
    j="$jTINY"
  fi
  runtestfc
done

