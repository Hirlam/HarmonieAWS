# Porting the Harmonie NWP model to AWS (Amazon Web Services)

This project describes the steps taken to port the [Harmonie system](http://hirlam.org/), a Canonical System Configuration 
(CSC) of the [ACCORD NWP model](http://www.umr-cnrm.fr/accord/), either entirely or in a simplified form, to run on AWS 
using [AWS ParallelCluster](https://aws.amazon.com/hpc/parallelcluster/).  The scripts
presented will expose all the steps required to build the base images, all model dependencies and 
finally the model itself. Moreover, the scripts can also be used to reproduce our results.

Having said that, please understand that this project is a POC (Proof Of Concept).

The TLDR process for running Harmonie in AWS is:

1. Sign up for an AWS account and install the AWS CLI (Command Line Interface) on your laptop
2. (OPTIONAL) Rebuild the Harmonie AMI (Amazon Machine Image) for your cluster 
3. Create the AWS cluster based either on our Harmonie AMI or a newly build AMI (cf. optional step 2)
4. Login to the HEAD node of the cluster with SSH and launch Harmonie, cf. instructions in 
   the AMI tailored README.txt file found once you login to the HEAD node of the cluster. 

# Step1: Setup AWS CLI

Once you have created an AWS account you should install the AWS CLI on your local machine:

```
$ pip install awscli
```

You can now easily interact with the different AWS services using the AWS CLI.

# Step2 (Optional): Create AWS AMIs with ready-to-use Harmonie binaries 

Amazon Machine Image (AMI) is an easy way to bake the required OS, applications and dependencies into an image
which can be used to launch instances on AWS. 

This (i.e. building AMI from scratch) is really an optional step. In case you only aim to run Harmonie experiments 
on AWS you can use our pre-build AMIs. At the moment there is no solid plans on which releases we intend to pre-build 
but in the future one could imagine that production releases would be pre-build automatically as one of the final 
stages in our CI/CD (Continuous Integration/Continuous Deployment) pipeline.

## Step2.1: Harmonie dependencies

For convenience, we will generate an [S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) 
for the files required for this project and add all the *external dependencies* to it.

First, the model source code itself: Note that you must have proper MOU agreements with the Hirlam-C Programme in place 
before you can get access to the Harmonie source code. The file `harmonie_source.tar.gz` is a wrap of the Harmonie 
source code (please make sure that it is updated with the recent port fixes). The Harmonie source code
is simply the `src/` and the `util/` sub-directory of any Hirlam Harmonie clone, e.g.

```
git clone -b harmonie-43h2.1.1 https://github.com/Hirlam/Harmonie harmonie_source
tar -zcvf harmonie_source.tar.gz harmonie_source/src harmonie_source/util
```

Next, there are some external library dependencies on top of a working Fortran and CC compiler 
suite, namely `cmake`, `eccodes`, `hdf5`, `netcdf-c` and `netcdf-fortran` that one will
have build first. We suggest that you simply copy these tarballs to a S3 bucket in order 
to avoid having to reload it from their individual upstream repository each time you 
wish to rebuild your AMI. 

The script `util/prepare_s3.sh` shows how one can take the tar files and move them to a 
common S3 bucket.

The remaining files required to reproduce this, i.e. to build and run Harmonie in AWS are
all present within this repository.

## Step2.2: Building the AMI

In case you wish to reproduce the builds then follow the below steps:

You need [packer](https://www.packer.io/downloads) on your local laptop in order
to generate the AMIs. Once that is established, please use the script to build Harmonie 
AMIs for the target instances you are aiming at. The sample script below will build AMIs 
for up to two instance types, namely Arm based AWS Graviton2 instances
`c6g` or `c6gn` and x86-64 based `c5n` instances but you can adjust the `TARGET` variable to suit your
specific needs.  Moreover, we show how to build with both the GNU and the Intel compiler suite.

The AWS Graviton2 Arm based instance type will use the GNU compiler with the MPI stack from OpenMPI
whereas the x86-64 based instance type will use the GNU compiler (or the Intel compiler),
the x86-64 builds will use the IntelMPI wrap of the MPI library.

Finally, you can choose if you wish to build a *benchmark AMI* or a complete *production AMI*. 
The latter allows you to use the complete Harmonie script suite and do full CYCLE runs whereas 
the former is focused on using simple scripts for running the forecast component only for 
benchmarking purposes. As this is merely a POC, we decided to show-case
an AMI image based on *Ubuntu 18.04* for the benchmark option and an AMI image based on 
*Ubuntu 20.04* for the production option.

```
./ami/build.sh [prodution|benchmark]
```

By studying the script `ami/generic/1.compiler.sh` one notes that we had to upgrade the `GNU` 
compiler suite from the default version on Ubuntu18.04. It turned out that the version of Harmonie 
that we are building here is broken with the 7.x version of the compiler that comes with Ubuntu18.04. 
Upgrading the compiler implies that external dependencies will have to be rebuild with the same 
version of the compiler so official Ubuntu packages cannot be used. Please consult the scripts 
in the AMI sub-directory for further details. They will expose all the details that
is required to build the Harmonie code itself and the base system image on which the
Harmonie code relies.

Eventually, the generation will complete and the tag for the new AMI will appear
(it will also appear in your AWS console if one prefer that interface). The tag
will be used in the cluster generation below.

```
....
==> amazon-ebs: Creating AMI Harmonie AMI Ubuntu 18.04 1619683662 from instance i-0e0c9968adae6f077
    amazon-ebs: AMI: ami-01286ed9ee2a1d93d
...
```

Or shorthand, lets just get the two newly generated AMI ID's by inspecting the log.txt of the
ami/build.sh script:

```
$ grep -i 'amazon-ebs: Adding tag: "Base_AMI_Name":' log.txt 
amazon-ebs: Adding tag: "Base_AMI_Name": "aws-parallelcluster-2.10.3-ubuntu-1804-lts-hvm-arm64-202103172101"
amazon-ebs: Adding tag: "Base_AMI_Name": "aws-parallelcluster-2.10.3-ubuntu-1804-lts-hvm-x86_64-202103172101"
$ grep -i '^us-east-1: ami-' log.txt|sort -u
us-east-1: ami-0306c3b6ce4b9dd13
us-east-1: ami-0c1319223fa78177e
$
```

So the first AMD ID is for the Arm cluster and the second is for the x86_64 cluster. 
Note that the AMI ID is tagged to a specific AWS region and when you generate new AMIs the AMI IDs will change.
So ensure to use the correct and updated AMI ID for your cluster in a specific region. 

The final AMI will have two sub-directories in, namely `harmonie/` and the `install/`. The first
contains the builds of the external library dependencies and the latter contains the Harmonie
binaries that have been built. The README.txt file will have content that reflects the relevant
instructions depending on whether the AMI was build as a benchmark target or a production target.

```
# Final AMI content (only binaries present so we can share the AMI without LICENSE issues)
ubuntu@ip-172-31-12-80:~$ ls -lrt
total 24
drwxrwxr-x 3 ubuntu ubuntu 4096 Aug 16 07:37 harmonie
drwxrwxr-x 3 ubuntu ubuntu 4096 Aug 16 09:01 install
-rw-rw-r-- 1 ubuntu ubuntu  502 Aug 16 09:01 README.txt
ubuntu@ip-172-31-12-80:~$ 
```

The README.txt file explains how one can use the binaries above to either launch benchmarks
on AWS or do full cycle runs using the usual Harmonie script suite and the underlying *ecflow* 
tool for orchestration, cf. sections below.

# AWS Parallelcluster Architecture and Configuration: 

## ParallelCluster Architecture:

The architecture below shows the relevant components and services used for configuring and 
running Harmonie on AWS. The templates in the parallelcluster directory will ensure that these 
components are set up correctly.

![](doc/aws-parallelcluster.png?raw=true)

## Harmonie Custom Amazon Machine Image (AMI):

- Contact the Harmonie system group in case you are interested in a custom Harmonie AMI 
- Please use the correct AMI ID for your architecture (Arm or x86-64) and AWS region.
- Note: AMI is associated with an Amazon EC2 Region. An instance needs to be launched in the same region as the AMI.

## ParallelCluster Configuration:

- You need to install [AWS Parallelcluster](https://github.com/aws/aws-parallelcluster) on your laptop in order to construct your AWS cluster.
- If you are new to AWS ParallelCluster refer to this [blog](https://aws.amazon.com/blogs/opensource/aws-parallelcluster/)
- To install AWS ParallelCluster refer to this [guide](https://docs.aws.amazon.com/parallelcluster/latest/ug/install.html)

  ```sh
  pip3 install aws-parallelcluster==2.10.4 --upgrade --user
  ```
  Important: The custom AMI provided is tied to a specific ParallelCluster version. So make sure to install the specific ParallelCluster version, in this case 2.10.4.

## Step3: Create the Cluster:

- To create the cluster, please run the following command:
  ```sh
  pcluster create <cluster-name> -c <path-to-config-file>
  ```
  
  ```sh
  #Example: Intel Skylake nodes (c5n.18xlarge) using Intel Compiler and IntelMPI:
  pcluster create x86-cluster -c parallelcluster/config.c5n-template -r us-east-1
  ```

  ```sh
  #Example: AWS Graviton2 Arm nodes (c6g.16xlarge, c6gn.16xlarge) using GNU8.4 and OpenMPI:
  pcluster create arm-cluster -c parallelcluster/config.c6g-template -r us-east-1
  ```

- You can list your created cluster as:
  ```sh
  pcluster list <cluster-name>
  ```

- Once the cluster is created, you can ssh to the cluster as:

  ```sh
  pcluster ssh <cluster-name>
  ```
  
  ```sh
  #Example
  pcluster ssh x86-cluster
  ```

- The cluster setup uses the [Auto-Scaling](https://docs.aws.amazon.com/parallelcluster/latest/ug/autoscaling.html) feature which means you only get a head node when you create a cluster.
  The Compute Nodes automatically come up when you launch your job. 

- In case you need to update your cluster configuration and/or stop/start your compute fleet in case you setup a static cluster, you can do the following:

  ```sh
  # To stop cluster/compute nodes
  pcluster stop <cluster-name>
  ```
  
  ```sh
  # To update cluster configuration for existing cluster
  pcluster update <cluster-name> -c <path-to-config-file>
  ```

  ```sh
  # To start cluster/compute nodes
  pcluster start <cluster-name>
  ```
 
- Note that the cluster configuration used above has multiple queues with instances for both AWS ENA and AWS EFA allowing one to
experiment with different interconnect once the cluster is up. 
- Moreover, the cluster supports both an NFS filesystem (Amazon EBS mounted via NFS) and a Lustre filesystem (using Amazon FSx for Lustre) so the proper filesystem can be chosen at runtime.

# Step4.1: Run Harmonie - benchmark AMI

Now once the cluster is created you can login to the head node in order to launch jobs. 
Once you launch your jobs the nodes required will be launched automatically. 
The only node that one will have to stop manually is the head node used to access the cluster. 
 

- You will use ssh to login to the head node:

``` sh
$ pcluster ssh <cluster-name> OR ssh -i <key> ubuntu@<IP>
$ cat README.txt # detailed instructions on howto use the binaries in the benchmark AMI
```

- To run using a small sample test-case
``` sh
$ git clone git@github.com/Hirlam/HarmonieAWS
$ cd HarmonieAWS/benchmark
$ ./runfc.sh
```

- To run with a large test-case
``` sh
$ cd /fsx # lustre
$ aws s3 cp big-testcase.tar.gz .
$ tar -zxvf big-testcase.tar.gz
$ cd ~/HarmonieAWS/benchmark
$ vi ./runfc.sh # adjust for the new testcase
$ ./runfc.sh # do the benchmarks.....
```

- Sample output (from small case) 
``` sh
Sample run # default is to repeat the run 5 times:
ubuntu@ip-172-31-12-120:~/aws4harm$ grep 'CNT4     - FORWARD INTEGRATION' benchmark/forecast/output-dQMXW4S5-GNU-AWS-INTELMPI-single-lustre-no-openmp-2x2x0x1.log 
   1 CNT4     - FORWARD INTEGRATION                  1    4480.3    4481.0     24.40      0.00
   1 CNT4     - FORWARD INTEGRATION                  1    4481.5    4483.0     68.29      0.02
   1 CNT4     - FORWARD INTEGRATION                  1    4478.5    4480.0     68.04      0.02
   1 CNT4     - FORWARD INTEGRATION                  1    4490.5    4492.0     68.11      0.02
   1 CNT4     - FORWARD INTEGRATION                  1    4496.5    4498.0     67.71      0.02
ubuntu@ip-172-31-12-120:~/aws4harm$ grep -i WAL benchmark/forecast/output-JIJt3j2t-GNU-AWS-INTELMPI-single-lustre-no-openmp-2x2x0x1.log 
        Wall-time is 6.51 sec on proc#1 (4 procs, 1 threads)
        Wall-time is 6.43 sec on proc#1 (4 procs, 1 threads)
        Wall-time is 6.45 sec on proc#1 (4 procs, 1 threads)
        Wall-time is 6.43 sec on proc#1 (4 procs, 1 threads)
        Wall-time is 6.44 sec on proc#1 (4 procs, 1 threads)
ubuntu@ip-172-31-12-120:~/aws4harm$ grep -C1 APP benchmark/forecast/output-JIJt3j2t-GNU-AWS-INTELMPI-single-lustre-no-openmp-2x2x0x1.log|grep '^[0-9]'
6.6
6.6
6.6
6.6
6.6
ubuntu@ip-172-31-12-120:~/aws4harm$ 
```

# Step4.2: Run Harmonie - production AMI

Now once the cluster is created you can login to the head node in order to launch full-cycle
experiments. Once you launch your experiment the nodes required for the individual jobs will 
be launched automatically. The only node that one will have to stop manually is the head node 
used to access the cluster. 

- You will use ssh to login to the head node:

``` sh
$ pcluster ssh <cluster-name> OR ssh -i <key> -X ubuntu@<IP>
$ cat README.txt # detailed instructions on how to use the binaries in the production AMI
```

The TLDR description:

1. Download input dataset for the experiment from S3.
2. Clone script-suite from your Harmonie repository
3. Run the full experiment on AWS using the usual Harmonie script-suite approach, i.e.

```
ecflow_start  # start ecflow to handle the orchestration
# download git export (assuming on-prem repository not directly reachable on AWS)
aws s3 cp s3://bucket-aws4harmonie/EXPNAME.tar.gz .
tar -zxvf EXPNAME.tar.gz 
# or preferable - clone directly from a public git export
git clone -b branchname git@repository/Harmonie.git EXPNAME
cd EXPNAME
./config-sh/Harmonie setup -r $(pwd) -h AWS.NEA-intel
export RELAUNCH=yes; sh Launch
```

Note in this example the Harmonie experiment is setup on the same directory as 
the git-checkout directory. This enables direct follow-up operation using git.
But this is a feature that requires a small script update in scr/InitRun.pl.

Example:

```
ubuntu@ip-172-31-12-80:~$ cd check-out/nea43
ubuntu@ip-172-31-12-80:~/check-out/nea43$ rm -f Env_submit Env_system config-sh/hm_rev # better safe than sorry
ubuntu@ip-172-31-12-80:~/check-out/nea43$ ./config-sh/Harmonie setup -r $(pwd) -h AWS.NEA-intel
Using reference installation at /home/ubuntu/check-out/nea43
new config-sh/hm_rev
Warning: config-sh/config.AWS.NEA-intel exists already; it will not be extracted anew
Warning: config-sh/submit.AWS.NEA-intel exists already; it will not be extracted anew
Warning: scr/include.ass exists already; it will not be extracted anew
Warning: config-sh/Main exists already; it will not be extracted anew
Warning: suites/harmonie.pm exists already; it will not be extracted anew
Warning: ecf/config_exp.h exists already; it will not be extracted anew
ubuntu@ip-172-31-12-80:~/check-out/nea43$ export RELAUNCH=yes; sh Launch
21-08-16 10:46:06 Harmonie: EXP not set, trying to derive it from cwd
21-08-16 10:46:06 Harmonie: I think EXP is nea43
21-08-16 10:46:06 Harmonie: this is /home/ubuntu/check-out/nea43
prod
to submit: DTG=2021081109 DTGEND=2021081109 DTGPP=2021081109 Actions continue 
 Harmonie: using Start to start an experiment.
loggings and error messages go to /shared/ubuntu/hm_home/nea43:
   /shared/ubuntu/hm_home/nea43/ECF.log contains log of ecflow
ubuntu@ip-172-31-12-80:~/check-out/nea43$ 
```

From here it should be usual Harmonie procedure that users are familiar with. If not, please
refer to [Harmonie documentation](http://hirlam.org) and 
the [ecflow documentation](https://confluence.ecmwf.int/display/ECFLOW/).

![](doc/ecflow-aws.png?raw=true)

# Community support of AMIs

We propose that AMIs will be generated as part of the CI chain for major releases
of the Harmonie suite. This will allow people within the community (as well as
collaborators outside the community) to run Harmonie experiments without having
to deal with the hassle of building the code. It will also provide as a common 
reference for runtime bug reports.

# Contributing

Feedback and contributions are very welcome! For specific proposals, please provide them as pull requests or issues via our GitHub site. 
For general discussion, feel free to reach out to the Hirlam system group.

# License 

Please read the [LICENSE](https://github.com/Hirlam/HarmonieAWS/blob/master/LICENSE)
