#!/bin/bash

#set -x

bold=$(tput bold)
normal=$(tput sgr0)
unline=$(tput smul)

usage() {

PROGNAME=`basename $0`

cat << EOFUSAGE

${bold}NAME${normal}
        ${PROGNAME} - Compile AHNS code for benchmarking purposes.

${bold}USAGE${normal}
        ${PROGNAME} -m <host name> [ -c <compiler> ] [ -p <precision> ]
                    [ -n <nproc> ] [-f configfile ] 
                    [ -d <src-dir> ] [ -i <install-dir> ] [ -h ]

${bold}DESCRIPTION${normal}
        Script to compile AHNS code for benchmarking purposes using HIRLAM's
        makeup system. makeup is wrapped around gmake.

${bold}OPTIONS${normal}
        -m ${unline}host name${normal}
            The name of your platform used in logic contained in this script.
            [ECMWF|METIE|LOCAL|UBUNTU|UBUNTUAWS]
 
        -c ${unline}compiler${normal}
            Compiler name used in logic contained in this script.
            [GNU|INTEL]
        
        -p ${unline}precision${normal}
            Compile code using single or double precision floating-point
            [single|double]

        -n ${unline}nproc${normal}
            Number of parallel compilation processes to run. Default: 1.

        -d ${unline}src-dir${normal}
            PATH to harmonie_src firectory. Default: \$HOME/harmonie_src

        -i ${unline}install-dir${normal}
            PATH for installation. Default: \$HOME/install

        -f ${unline}configfile${normal}

        -h Help! Print usage information.

EOFUSAGE
}

HOST=ECMWF                  # Host ECMWF|METIE|LOCAL|UBUNTU
CS=GNU                      # Compiling system GNU|INTEL
FP_PRECISION=double         # double|single floating point precision
NPROC=4                     # number of parallel processes for make
DISTDIR=$HOME/harmonie_src  # PATH to the source code
INSTDIR=$HOME/install       # Where to install libraries/executables

USAGE=0

while getopts m:c:p:n:d:i:f:h option
do
  case $option in
    m)
       HOST=$OPTARG
       ;;
    c)
       CS=$OPTARG
       ;;
    p)
       FP_PRECISION=$OPTARG
       ;;
    n)
       NPROC=$OPTARG
       ;;
    d)
       DISTDIR=$OPTARG
       ;;
    f)
       export CONFIG=$OPTARG
       ;;
    i)
       INSTDIR=$OPTARG
       ;;
    h)
       USAGE=1
       ;;
    *)
       USAGE=1
       ;;
  esac
done

if [ ${USAGE} -eq 1 -o "$#" -eq 0 ]; then
  usage
  exit 1
fi

export FP_PRECISION

BMDIR=`pwd`                       # This directory

if [ $HOST == ECMWF ]
then
   if [ $CS == GNU ]
   then
      . share/choose_PrgEnv.cca gnu
      export CONFIG=cca.gnu
   elif [ $CS == INTEL ]
   then
      . share/choose_PrgEnv.cca intel
      export CONFIG=cca.intel
   else
      echo Unknown Compiling System $CS
      exit 1
   fi
elif [ $HOST == METIE ]
then
   if [ $CS == GNU ]
   then
      module purge
      module load mpi/openmpi-x86_64
      module load eccodes/gnu-4.8.5/2.8.2
      export CONFIG=redhat7.gfortran.openmpi
      export ECCODES=/opt/metapp/eccodes/2.8.2/gnu/4.8.5
   else
      echo Unknown Compiling System $CS
      exit 1
   fi
elif [ $HOST == LOCAL ]
then
   if [ $CS == GNU ]
   then
      export CONFIG=linux.gfortran.mpi.gcc
      export ECCODES=/usr
      export ECCODES_DEFINITION_PATH=$ECCODES/share/eccodes/definitions
      export ECCODES_INCLUDE=-I$ECCODES/lib/x86_64-linux-gnu/fortran/gfortran-mod-15
      export ECCODES_LIB="-L$ECCODES/lib -leccodes_f90 -leccodes"
      export NETCDF=/usr
      export NETCDF_INCLUDE=-I$NETCDF/include
      export NETCDF_LIB="-L$NETCDF/lib -lnetcdff -lnetcdf"
      export HDF5=/usr
      export HDF5_INCLUDE=-I$HDF5/include/hdf5/serial
      export HDF5_LIB="-L$HDF5/lib/x86_64-linux-gnu/hdf5/serial -lhdf5hl_fortran -lhdf5_fortran -lhdf5"
   elif [ $CS == INTEL ]
   then
      export CONFIG=linux.ifort.mpi
      export GRIB_API=$HOME/grib_api
      export GRIB_API_LIB="-L$GRIB_API/lib -lgrib_api_f90 -lgrib_api"
      export GRIB_API_INCLUDE=-I$GRIB_API/include
      export NETCDF=$HOME/netcdf
      export HDF5=/lustre1/operation/prodharm/hdf5/hdf5-1.8.21/
   else
      echo Unknown Compiling System $CS
      exit 1
   fi
elif [ $HOST == UBUNTU ]
then
   if [ $CS == GNU ]
   then
      export CONFIG=linux.gfortran.mpi.ubuntu18.04
      export ECCODES=/home/uwc/harmonie/GNU/eccodes
      export ECCODES_DEFINITION_PATH=$ECCODES/share/eccodes/definitions
      export ECCODES_INCLUDE=-I$ECCODES/lib/x86_64-linux-gnu/fortran/gfortran-mod-15
      export ECCODES_LIB="-L$ECCODES/lib -leccodes_f90 -leccodes"
      export NETCDF=/home/uwc/harmonie/GNU/netcdf
      export NETCDF_INCLUDE=-I$NETCDF/include
      export NETCDF_LIB="-L$NETCDF/lib -lnetcdff -lnetcdf"
      export HDF5=/home/uwc/harmonie/GNU/hdf5
      export HDF5_INCLUDE=-I$HDF5/include/hdf5/serial
      export HDF5_LIB="-L$HDF5/lib/x86_64-linux-gnu/hdf5/serial -lhdf5hl_fortran -lhdf5_fortran -lhdf5"
   else
      echo Unknown Compiling System $CS
      exit 1
   fi
elif [ $HOST == UBUNTUAWS ]
then
   if [ $CS == GNU ]
   then
      export ECCODES=/home/ubuntu/harmonie/GNU/eccodes
      export ECCODES_DEFINITION_PATH=$ECCODES/share/eccodes/definitions
      export ECCODES_INCLUDE=-I$ECCODES/lib/x86_64-linux-gnu/fortran/gfortran-mod-15
      export ECCODES_LIB="-L$ECCODES/lib -leccodes_f90 -leccodes"
      export NETCDF=/home/ubuntu/harmonie/GNU/netcdf
      export NETCDF_INCLUDE=-I$NETCDF/include
      export NETCDF_LIB="-L$NETCDF/lib -lnetcdff -lnetcdf"
      export HDF5=/home/ubuntu/harmonie/GNU/hdf5
      export HDF5_INCLUDE=-I$HDF5/include/hdf5/serial
      export HDF5_LIB="-L$HDF5/lib/x86_64-linux-gnu/hdf5/serial -lhdf5hl_fortran -lhdf5_fortran -lhdf5"
   elif [ $CS == INTEL ]
   then
      export ECCODES=/home/ubuntu/harmonie/INTEL/eccodes
      export ECCODES_DEFINITION_PATH=$ECCODES/share/eccodes/definitions
      export ECCODES_INCLUDE=-I$ECCODES/lib/x86_64-linux-gnu/fortran/gfortran-mod-15
      export ECCODES_LIB="-L$ECCODES/lib -leccodes_f90 -leccodes"
      export NETCDF=/home/ubuntu/harmonie/INTEL/netcdf
      export NETCDF_INCLUDE=-I$NETCDF/include
      export NETCDF_LIB="-L$NETCDF/lib -lnetcdff -lnetcdf"
      export HDF5=/home/ubuntu/harmonie/INTEL/hdf5
      export HDF5_INCLUDE=-I$HDF5/include/hdf5/serial
      export HDF5_LIB="-L$HDF5/lib/x86_64-linux-gnu/hdf5/serial -lhdf5hl_fortran -lhdf5_fortran -lhdf5"
   else
      echo Unknown Compiling System $CS
      exit 1
   fi
else
   echo Unknown Host $HOST
   exit 1
fi

echo " ... installing code in $INSTDIR/${CS}/${FP_PRECISION} for Host=$HOST, CS=$CS, config=$CONFIG"

mkdir -p $INSTDIR/${CS}/${FP_PRECISION}
cd $INSTDIR/${CS}/${FP_PRECISION}

echo " ... copying code to $INSTDIR/${CS}/${FP_PRECISION}"
cp -R $DISTDIR/src $DISTDIR/util .

if [ -s $BMDIR/share/config.$CONFIG ] ; then
  echo " ... using config file available in benchmark: $BMDIR/share/config.$CONFIG"
  cp $BMDIR/share/config.$CONFIG util/makeup/
elif [ -s util/makeup/config.$CONFIG ] ; then
  echo " ... using config file available in makeup: $DISTDIR/util/makeup/config.$CONFIG"
else
  echo "config file not found"
  exit 1
fi

cd src

echo " ... "
echo " ... configuration output in $INSTDIR/${CS}/${FP_PRECISION}/config.log"
echo " ... "
echo " ... START BENCHMARK TIMING: " $(date -u +%s)
echo " ... "
../util/makeup/configure -d config.$CONFIG 2>&1 | tee $INSTDIR/${CS}/${FP_PRECISION}/config.log 

echo " ... "
echo " ... compilation using ${NPROC} simultaneous jobs"
echo " ... compilation output in $INSTDIR/${CS}/${FP_PRECISION}/make.log"
echo " ... compiling ..."
echo " ... "
echo " ... please be patient!"
echo " ... "
make CMDROOT=`pwd`/../util/makeup ROOT=`pwd` LIBDISK=`pwd` NPES=${NPROC} 2>&1 | tee $INSTDIR/${CS}/${FP_PRECISION}/make.log 

echo " ... "
echo " ... STOP BENCHMARK TIMING: " $(date -u +%s)
echo " ... "
echo " ... Binaries installed in $INSTDIR/${CS}/${FP_PRECISION}/install/bin"

if [ -s $INSTDIR/${CS}/${FP_PRECISION}/install/bin/MASTERODB ] ; then
  echo " ... success, I hope!"
  ls -l "$INSTDIR/${CS}/${FP_PRECISION}/install/bin/MASTERODB"
  echo " ... compilation complete"
  exit 0
else
  echo " ... failure, I think!"
  ls -l "$INSTDIR/${CS}/${FP_PRECISION}/install/bin/MASTERODB"
  echo " ... compilation incomplete"
  echo " ... check contents of config.log and make.log"
  exit 1
fi

