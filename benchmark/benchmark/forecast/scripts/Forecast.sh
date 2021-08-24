#!/bin/bash


set -e # stop the shell on first error

# Trap any calls to exit and errors caught by the -e flag
trap ERROR 0

# Trap any signal that may cause the script to fail
trap '{ echo "Killed by a signal"; ERROR ; }' 1 2 3 4 5 6 7 8 10 12 13 15

#-----------------------------------------------------------------------
# Run Forecast (configuration 001 of ARPEGE/IFS model):
#---------------------------------------------------------------------
# Inputs:
#
#-----------------------------------------------------------

trap "exit 1" 0

#-- enter the working dir
cd ${d_FORECAST}  || exit 1

#--- fetch rrtm files
ln -sf ${INPUT_DATA}/inputConst/rrtm_const/* .

#--- fetch ECOCLIMAP files
ln -sf ${INPUT_DATA}/inputModel/*.bin .

cd $d_FORECAST/

#--- model namelist
cp ${BMDIR}/namelists/namelist_forecast_${DOMAIN} fort.4
if [ ${NPROC_IO} -gt 0 ] ; then
  echo ${INPUT_DATA}/inputFcast/$DOMAIN | sed 's/\//\\\//g' > cifstr.tmp
  CIFSTR=`cat cifstr.tmp` && rm -f cifstr.tmp
  sed -i "s/__BMCIFDIR__/\"${CIFSTR}\"/g" fort.4
else
  sed -i "s/__BMCIFDIR__/\"\"/g" fort.4
fi

sed -i "s/__BMNPROC__/${NPROCXY}/g" fort.4
sed -i "s/__BMNPROCX__/${NPROCX}/g" fort.4
sed -i "s/__BMNPROCY__/${NPROCY}/g" fort.4
sed -i "s/__BMNPROC_IO__/${NPROC_IO}/g" fort.4
sed -i "s/__BMFCLEN__/h${FCLEN}/g" fort.4

#--- SURFEX namelist
cp ${BMDIR}/namelists/EXSEG1_forecast_${DOMAIN}.nam EXSEG1.nam

# Copy the surfex file
ln -sf ${INPUT_DATA}/inputModel/${DOMAIN}/Const.Clim.sfx         Const.Clim.sfx
ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/fc_start_sfx           ICMSHHARMINIT.sfx

# Get start file and lateral boundaries
ln -sf ${INPUT_DATA}/inputModel/${DOMAIN}/Const.Clim             const.clim.${DOMAIN}
ln -sf ${INPUT_DATA}/inputModel/${DOMAIN}/Const.Clim             Const.Clim
ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/fc_start               ICMSHHARMINIT

if [ $DOMAIN == "HUGE" ] ; then
  export MPL_MBX_SIZE=1200000000
  NLEV=90
  for FF in `seq -f %02g 0 1 ${FCLEN}` ; do
    ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/ELSCFHARMALBC0${FF} ELSCFHARMALBC0${FF}
  done
elif [ $DOMAIN == "TINY" ] ; then
  export MPL_MBX_SIZE=628000000
  NLEV=60
  ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/ELSCFHARMALBC000    ELSCFHARMALBC000
  ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/ELSCFHARMALBC001    ELSCFHARMALBC001
  ln -sf ${INPUT_DATA}/inputFcast/${DOMAIN}/ELSCFHARMALBC002    ELSCFHARMALBC002
else
  echo " ... Unknown domain; aborting!"
  exit 1
fi
#--- FULLPOS directives
cp ${BMDIR}/namelists/xxt00000000 xxt00000000
cp ${BMDIR}/namelists/xxtddddhhmm xxtddddhhmm
sed -i "s/__BMDOMAIN__/${DOMAIN}/g" xxt*
sed -i "s/__BMNLEV__/${NLEV}/g" xxt*
cp ${BMDIR}/namelists/dirlst      dirlst

# Reduce amount of useless zeros at end
export EC_PROFILE_HEAP=0

# Set MBX_SIZE, application mailbox size
export MBX_SIZE=${MPL_MBX_SIZE}

ls $BINDIR/MASTERODB
ldd $BINDIR/MASTERODB

n=1
echo "Inner job loop trip-count is set to: $REPEAT"
while [ $n -le $REPEAT ]
do
  mpirun -np ${NODES} ${HOME}/set_kernel_parameters.sh
  echo " ... $MPPEXEC $BINDIR/MASTERODB"
  echo " ... START BENCHMARK TIMING: `date -u +%s`"
  $MPPEXEC $BINDIR/MASTERODB $MPPEXECP || exit 1
  echo " ...  STOP BENCHMARK TIMING: `date -u +%s`"
  echo " ... "
  echo " ... APP TIME IN SECONDS"
  grep "TOTAL WALLCLOCK TIME" NODE.001_01 |awk '{print $4}'
  echo " ... APP TIME"

  if [ "$DOMAIN" == "HUGE" -a $FCLEN -eq 48 ] ; then
    echo " ... VALIDATION"
    grep -A 3 -i 'NORMS AT NSTEP CNT4 2880' NODE.001_01
    echo " ... VALIDATION"
  fi
 rm -f PF*00* */PF*00*
 rm -f IC*00* */IC*00*
 grep -A29 '===-=== START OF TIMING STATISTICS ===-===' NODE.001_01
 n=$(( $n + 1 ))
done

# Normal exit
cd $WRK

trap - 0
exit

