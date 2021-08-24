#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
unline=$(tput smul)

usage() {

PROGNAME=$(basename $0)

cat << EOFUSAGE

${bold}NAME${normal}
        ${PROGNAME} - Run forecast component of the AHNS. 

${bold}USAGE${normal}
        ${PROGNAME} -m <host-name> -x <nprocx> -y <nprocy>
                    [ -s <nproc_io> ] [ -t <threads> ]
                    [ -d <model-domain> ]
                    [ -l <forecast-length> ]
                    [ -b <binary-directory> ]
                    [ -p <partition> ]
                    [ -r <number_of_repeated_runs_within_same_job> ]
                    [ -i <input-directory> ] [ -o <output-directory> ]
                    [ -h ]

${bold}DESCRIPTION${normal}
        Script to run Forecast component of the AHNS. This script can create
        batch submission headers and run a sample forecast.


${bold}OPTIONS${normal}
        -m ${unline}host name${normal}
            The name of your platform used in logic contained in this script.
            [ECMWF|LOCAL]
 
        -x ${unline}nprocx${normal}
            Number of processors in x-direction for 2D domain decomposition
        
        -y ${unline}nprocy${normal}
            Number of processors in y-direction for 2D domain decomposition
        
        -s ${unline}nproc_io${normal}
            Number of processors for the IO-server [ default : 0 ]
        
        -t ${unline}threads${normal}
            Number of OpenMP threads [ default : 1 ]
        
        -d ${unline}model-domain${normal}
            Model domain [TINY|HUGE  default : HUGE ]
        
        -l ${unline}forecast-length${normal}
            Length of forecast in hours [ default : 48 ]
        
        -b ${unline}binary-directory${normal}
            PATH to binaries (including MASTERODB) compiled using build.sh

        -i ${unline}input-directory${normal}

        -o ${unline}output-directory${normal}

        -h Help! Print usage information.

EOFUSAGE
}


REPEAT=1
NPROCX=-1
NPROCY=-1
NPROC_IO=0
THREADS=1
DOMAIN=HUGE
FCLEN=6
HOST=ECMWF                  # Host ECMWF|LOCAL
BINDIR=$HOME/install/bin    # Where to install libraries/executables
INPDIR=$HOME/bmInputs       # Where to install libraries/executables
OUTDIR=$HOME/bmForecast     # Where to install libraries/executables
PARTITION="od-queue" # od-queue2 for C5n and od-queue1 for C5

USAGE=0

while getopts m:x:y:s:t:d:l:b:i:o:p:h:r: option
do
  case $option in
    m)
       HOST=$OPTARG
       ;;
    x)
       NPROCX=$OPTARG
       ;;
    y)
       NPROCY=$OPTARG
       ;;
    s)
       NPROC_IO=$OPTARG
       ;;
    t)
       THREADS=$OPTARG
       ;;
    d)
       DOMAIN=$OPTARG
       ;;
    l)
       FCLEN=$OPTARG
       ;;
    b)
       BINDIR=$OPTARG
       ;;
    i)
       INPDIR=$OPTARG
       ;;
    o)
       OUTDIR=$OPTARG
       ;;
    r)
       REPEAT=$OPTARG
       ;;
    p)
       PARTITION=$OPTARG
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

if [ ${NPROCX} -lt 1 -o ${NPROCY} -lt 1 ]; then
  echo "Invalid NPROC settings: ${NPROCX},  ${NPROCY}"
  exit 1
fi
# guess number of cores
dpkg --print-architecture |grep amd64 && NTPN=36
dpkg --print-architecture |grep arm64 && NTPN=16
#
# Calculate NPROC and NPROCXY
#
NPROCXY=`expr ${NPROCX} \* ${NPROCY}`
NPROC=`expr ${NPROCXY} + ${NPROC_IO}`
NPROCM1=`expr ${NPROC} + -1`
MAXNODES=$(echo "( $NPROC + 36 -1 )/36" | bc)
if [[ $NTPN == 36 ]] && [[ ${THREADS} -gt 1 ]]; then 
  NTPN=`expr 36 / ${THREADS}`
fi
NNODES=$(printf %1.0f $(echo " ${NPROC} / ${NTPN}" | bc -l)) 
echo "Running on $NNODES each with $NTPN tasks and $THREADS threads"

TAG="noprec"
FSTAG="nfs"
STACKTAG="MISSING"
echo $BINDIR | grep -i "single" && TAG="single"
echo $BINDIR | grep -i "double" && TAG="double"
echo $OUTDIR | grep -i "/fsx" && FSTAG="lustre"
echo $BINDIR | grep -i "avx2-tbb" && BTAG="avx2-tbb"
echo $BINDIR | grep -i "/avx2/" && BTAG="avx2"
echo $BINDIR | grep -i "/avx512/" && BTAG="avx512"

# set COMPILER (ARM GNU, x86-64 GNU or Intel)
dpkg -l|grep gfortran-8 && COMPILER=GNU
dpkg -l|grep intel-oneapi-compiler-fortran && COMPILER=INTEL
dpkg --print-architecture |grep arm64 && export STACKTAG="AWS-OPENMPI"
dpkg --print-architecture |grep amd64 && export STACKTAG="AWS-INTELMPI"
if [[ x$COMPILER == xINTEL ]]; then
  dpkg --print-architecture |grep amd64 && export STACKTAG="INTELMPI"
fi

UNIQTAG=$(mktemp -u XXXXXXXX)

export BMDIR=$(pwd) # benchmark directory

if [ ${HOST} == "ECMWF" ] ; then

  cat << EOFBATCH > batch.tmp
#-- host specific settings added by $0
#PBS -q np
#PBS -j oe
#PBS -N bmForecast${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}
#PBS -m n
#PBS -o bmForecast${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}.log
#PBS -l EC_memory_per_task=3505MB
#PBS -l EC_tasks_per_node=1:36
#PBS -l EC_threads_per_task=1
#PBS -l EC_total_tasks=1:${NPROC}

export LOADHUGEPAGES="yes"
ulimit -S -s unlimited || ulimit -s
ulimit -S -m unlimited || ulimit -m
ulimit -S -d unlimited || ulimit -d

export MPPEXEC="aprun -n 1 -N 1"
export MPPEXECP=": -n $NPROCM1 $BINDIR/MASTERODB"

#-- set up environment at ECMWF
. ${BMDIR}/share/choose_PrgEnv.cca gcc

# MPI/OpenMP settings
export OMP_DYNAMIC=false
export OMP_NUM_THREADS=1
export MPICH_MAX_THREAD_SAFETY=multiple
export MPICH_VERSION_DISPLAY=1

# DR_HOOK
export DR_HOOK=1
export DR_HOOK_IGNORE_SIGNALS=8
export DR_HOOK_SHOW_PROCESS_OPTIONS=0

#-- END host specific settings added by $0

EOFBATCH

  SUBMIT=qsub

elif [ ${HOST} == "AWS" ] ; then
  cat << EOFBATCH > batch.tmp
#-- host specific settings added by $0
##
## INSERT batch directives here
##
#SBATCH --job-name=forecast
#SBATCH --output=output-${UNIQTAG}-${COMPILER}-${STACKTAG}-$TAG-$FSTAG-$BTAG-${NPROCX}x${NPROCY}x${NPROC_IO}x${THREADS}.log
#SBATCH --ntasks=${NPROC}
#SBATCH --ntasks-per-node=${NTPN}
#SBATCH --cpus-per-task=${THREADS}
#SBATCH --nodes=${MAXNODES} # Maximum number of nodes to be allocated
#SBATCH --partition=${PARTITION}
#SBATCH --exclusive
#SBATCH --time=00:30:00

ELIBDIR=/home/ubuntu/harmonie/$COMPILER

if [[ ${STACKTAG} == "AWS-INTELMPI" ]]; then
  export I_MPI_OFI_LIBRARY_INTERNAL=0
  export I_MPI_DEBUG=5
  module load intelmpi
  module load libfabric-aws/1.11.1amzn1.0
  export MPPEXEC="/opt/intel/impi/2019.8.254/intel64/bin/mpirun -np ${NPROC}" # intelMPI
fi

if [[ ${STACKTAG} == "AWS-OPENMPI" ]]; then
  # ARM - cg6n
  module load openmpi/4.1.0 # aws-parallelcluster-2.10.3-ubuntu-1804
  module load libfabric-aws/1.11.1amzn1.0
  export MPPEXEC="mpirun -np ${NPROC}" # openmpi
fi

When running

if [[ ${STACKTAG} == "INTELMPI" ]]; then
  # If you want to use the “libfabric” provided by IntelMPI, add the following env variables:
  export I_MPI_OFI_LIBRARY_INTERNAL=1
  export I_MPI_DEBUG=5
  source /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh -arch intel64 -platform linux # intel oneAPI MPI or the intel MPI from ParallelCluster 
  # If you want to use the “libfabric” provided by AWS ParallelCluster
#  export I_MPI_OFI_LIBRARY_INTERNAL=0
#  export I_MPI_DEBUG=5
#  source /opt/intel/compilers_and_libraries/linux/bin/compilervars.sh -arch intel64 -platform linux # intel oneAPI MPI or the intel MPI from ParallelCluster 
#  module load libfabric-aws/1.11.1amzn1.0

  export LD_LIBRARY_PATH="/opt/intel/oneapi/mkl/2021.2.0/lib/intel64:/opt/intel/oneapi/compiler/2021.2.0/linux/compiler/lib/intel64_lin:\$LD_LIBRARY_PATH"

  # Huge Pages
  if [[ ${BTAG} == "avx2-tbb" ]]; then
    echo "Setting TBB env"
    export LD_LIBRARY_PATH=/opt/intel/oneapi/tbb/2021.2.0/lib/intel64/gcc4.8:\$LD_LIBRARY_PATH
    export TBB_MALLOC_USE_HUGE_PAGES=1
  fi
  export MPPEXEC="mpirun -np ${NPROC}" # intelmpi, default numa
fi

export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu/:\$ELIBDIR/netcdf/lib:\$ELIBDIR/eccodes/lib:\$ELIBDIR/hdf5/lib:\$LD_LIBRARY_PATH"

NODES=$(echo "( $NPROC + ${NTPN} -1 )/${NTPN}" | bc)
export NODES="\${NODES}"
echo "repeast is ${REPEAT}"
export REPEAT="${REPEAT}"
command -v mpirun
echo "Running on $NNODES each with $NTPN tasks and $THREADS threads"
echo "Running with ${NPROC} tasks using \${NODES} nodes"

env|grep LD_LIBRARY_PATH
ulimit -S -s unlimited || ulimit -s
ulimit -S -m unlimited || ulimit -m
ulimit -S -d unlimited || ulimit -d


# MPI/OpenMP settings
export OMP_DYNAMIC=false
export OMP_NUM_THREADS=${THREADS}
export OMP_STACKSIZE=4G
export MPICH_MAX_THREAD_SAFETY=multiple
export MPICH_VERSION_DISPLAY=1

export DR_HOOK=0                       # Turn it off
export DR_HOOK_IGNORE_SIGNALS=8
export DR_HOOK_SILENT=1                # 0|1
export DR_HOOK_OPT=prof                # calls,cputime,walltime,times,heap,stack,rss
                                       # paging,memory,all,prof,cpuprof,hpmprof,trim,self
export DR_HOOK_SHOW_PROCESS_OPTIONS=0
export DR_HOOK_PROFILE=drhook.prof.%d

module list
env

#-- END host specific settings added by $0

EOFBATCH

  SUBMIT="sbatch"

elif [ ${HOST} == "LOCAL" ] ; then
  cat << EOFBATCH > batch.tmp
#-- host specific settings added by $0
##
## INSERT batch directives here
##

ulimit -S -s unlimited || ulimit -s
ulimit -S -m unlimited || ulimit -m
ulimit -S -d unlimited || ulimit -d

#METIE
export DR_HOOK=1
export DR_HOOK_IGNORE_SIGNALS=8
export DR_HOOK_SILENT=1                # 0|1
export DR_HOOK_OPT=prof                # calls,cputime,walltime,times,heap,stack,rss
                                       # paging,memory,all,prof,cpuprof,hpmprof,trim,self
export DR_HOOK_SHOW_PROCESS_OPTIONS=0
export DR_HOOK_PROFILE=drhook.prof.%d

export MPPEXEC="mpirun -np ${NPROC}"
#-- END host specific settings added by $0

EOFBATCH

  SUBMIT=""

else

  echo "ERROR: host not supported ... exiting"
  exit 1

fi

#-- create a output directory
WRK=${OUTDIR}
echo " ... output-directory: ${WRK}" 

WDIR=wrkForecast_${COMPILER}-${STACKTAG}-$TAG-$FSTAG-${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}
d_FORECAST=${WRK}/${WDIR}.${UNIQTAG}

echo " ... run-directory   : ${d_FORECAST}" 

cat << EOFENVDEF >> batch.tmp
#--variable definitions added by $0

export NPROCX=${NPROCX}
export NPROCY=${NPROCY}
export NPROCXY=${NPROCXY}
export NPROC_IO=${NPROC_IO}
export NPROC=${NPROC}
export DOMAIN=${DOMAIN}
export FCLEN=${FCLEN}
export BINDIR=${BINDIR}
export OMP_NUM_THREADS=${THREADS}

#-- set input directory
INPUT_DATA=${INPDIR}

#-- set work/output directory
d_FORECAST=${d_FORECAST}
mkdir -p ${d_FORECAST}

#-- define code locations
export BMDIR=${BMDIR}          # benchmark directory

#-- END variable definitions added by $0

EOFENVDEF

echo " ... fetch Forecast.sh script template from scripts"
cp scripts/Forecast.sh Forecast-${UNIQTAG}-${COMPILER}-${STACKTAG}-${TAG}-${FSTAG}_${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}.sh

echo " ... add system specific settings and required enviironment variables"
sed  -i '2r batch.tmp' Forecast-${UNIQTAG}-${COMPILER}-${STACKTAG}-${TAG}-${FSTAG}_${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}.sh && rm -f batch.tmp

echo " ... submit job with ... "
echo " ...                     ${SUBMIT} ./Forecast-${UNIQTAG}-${COMPILER}-${STACKTAG}-${TAG}-${FSTAG}_${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}.sh"
echo " "
${SUBMIT} ./Forecast-${UNIQTAG}-${COMPILER}-${STACKTAG}-${TAG}-${FSTAG}_${NPROCX}_${NPROCY}_${NPROC_IO}_${THREADS}.sh

exit 0
