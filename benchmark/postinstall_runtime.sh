#!/bin/bash

# We have seen that we cannot get reproducible timings unless we wait 10 minutes before we start to use the compute nodes. Otherwise
# our initial timings on the job will be severly impacted by OS jitter. This jitter were found to stem from unattended-upgrades, cf.
# (https://github.com/aws/aws-parallelcluster/wiki/Create-Ubuntu-AMI-with-Unattended-Upgrades-disabled). 
# TODO move this fix to the AMI generation

# Alas, having this as a post-install script does not seem to remove the jitter entirely, we still have to await 10 minutes before 
# the nodes can be used if we insist on a jitter-free experience looking at 

echo "Post-install for compute nodes for cluster for START"
apt remove -y unattended-upgrades # A failed attempt to fix the sleep 600 need on AWS
exit 0

# Jitter test1: grep 'FORWARD INTEGRATION'
# With both 10 min wait and with the post-install above, we see:

#ubuntu@ip-172-31-1-10:~/aws4harm$ grep 'FORWARD INTEGRATION' benchmark/forecast/output-LpAOJMje-GNU-MISSING-single-lustre-no-openmp-19x20x0x1.log
#   1 CNT4     - FORWARD INTEGRATION                  1  511559.6  511596.0     82.52      0.01
#   1 CNT4     - FORWARD INTEGRATION                  1  512158.1  512195.0     91.57      0.01
#   1 CNT4     - FORWARD INTEGRATION                  1  511310.6  511346.0     91.63      0.01
#   1 CNT4     - FORWARD INTEGRATION                  1  511156.1  511194.0     91.57      0.01
#   1 CNT4     - FORWARD INTEGRATION                  1  511582.7  511620.0     91.59      0.01

# Jitter test2: Wall-time
#ubuntu@ip-172-31-1-10:~/aws4harm$ grep -i WALL benchmark/forecast/output-LpAOJMje-GNU-MISSING-single-lustre-no-openmp-19x20x0x1.log
#        Wall-time is 616.25 sec on proc#1 (380 procs, 1 threads)
#        Wall-time is 555.14 sec on proc#1 (380 procs, 1 threads)
#        Wall-time is 554.20 sec on proc#1 (380 procs, 1 threads)
#        Wall-time is 554.42 sec on proc#1 (380 procs, 1 threads)
#        Wall-time is 554.75 sec on proc#1 (380 procs, 1 threads)
#ubuntu@ip-172-31-1-10:~/aws4harm$

# Jitter test3: outer timer, cf. benchmark/forecast/scripts/Forecast.sh
#ubuntu@ip-172-31-1-10:~/aws4harm$ grep -C1 APP benchmark/forecast/output-LpAOJMje-GNU-MISSING-single-lustre-no-openmp-19x20x0x1.log|grep '^[0-9]'
#620.0
#559.3
#558.0
#558.3
#558.6
#ubuntu@ip-172-31-1-10:~/aws4harm$


# Jitter test1: passed
# Jitter test2: Not passed
# Jitter test3: Not passed

