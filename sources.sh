#!/bin/bash

apt-get update
mpich_repoversion=$(apt-cache policy mpich | grep Candidate | cut -d ':' -f 2 | cut -d '-' -f 1 | cut -c2)
if [ "$mpich_repoversion" -ge 4 ]; then
    mpirun_packages="libopenmpi-dev libhdf5-openmpi-dev"
else
    mpirun_packages="mpich libhdf5-mpich-dev"
fi
apt-get install -y build-essential csh gfortran m4 curl perl \
    ${mpirun_packages} libpng-dev netcdf-bin libnetcdff-dev cmake


package4checks="build-essential csh gfortran m4 curl perl ${mpirun_packages} libpng-dev netcdf-bin libnetcdff-dev"
for packagecheck in ${package4checks}; do
 packagechecked=$(dpkg-query --show --showformat='${db:Status-Status}\n' $packagecheck | grep not-installed)
 if [ "$packagechecked" = "not-installed" ]; then
        echo $packagecheck "$packagechecked"
     packagesnotinstalled=yes
 fi
done

echo "" >> ~/.bashrc
bashrc_exports=("#WRF Variables" "export DIR=$(pwd)" "export CC=gcc" "export CXX=g++" "export FC=gfortran" "export FCFLAGS=-m64" "export F77=gfortran" "export FFLAGS=-m64"
		"export NETCDF=/usr" "export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/serial" "export LDFLAGS="\""-L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -L/usr/lib"\"""
		"export CPPFLAGS="\""-I/usr/include/hdf5/serial/ -I/usr/include"\""" "export LD_LIBRARY_PATH=/usr/lib")
for bashrc_export in "${bashrc_exports[@]}" ; do
[[ -z $(grep "${bashrc_export}" ~/.bashrc) ]] && echo "${bashrc_export}" >> ~/.bashrc
done

exit
# Exit shell