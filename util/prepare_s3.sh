#!/usr/bin/env bash 

#
# prepare external dependencies, get source files and upload to S3 bucket
#

set -o errexit
set -o nounset
set -o pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {

  test -f harmonie_source.tar.gz && aws s3 cp harmonie_source.tar.gz s3://bucket-aws4harmonie || exit 1

  wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.0/src/hdf5-1.12.0.tar.gz || exit 1
  aws s3 cp hdf5-1.12.0.tar.gz s3://bucket-aws4harmonie || exit 1

  wget https://www.unidata.ucar.edu/downloads/netcdf/ftp/netcdf-fortran-4.5.3.tar.gz || exit 1
  aws s3 cp netcdf-fortran-4.5.3.tar.gz s3://bucket-aws4harmonie || exit 1

  wget https://www.unidata.ucar.edu/downloads/netcdf/ftp/netcdf-c-4.7.4.tar.gz || exit 1
  aws s3 cp netcdf-c-4.7.4.tar.gz s3://bucket-aws4harmonie || exit 1

  wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.17.0-Source.tar.gz || exit 1
  aws s3 cp eccodes-2.17.0-Source.tar.gz s3://bucket-aws4harmonie || exit 1

  wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3.tar.gz || exit 1
  aws s3 cp cmake-3.17.3.tar.gz s3://bucket-aws4harmonie || exit 1

  aws s3 ls s3://bucket-aws4harmonie
}

main "${@}"
