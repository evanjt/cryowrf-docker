#!/bin/bash
#########################################################
#		WRF Install Script     			#
# 	This Script was written by Umur Dinç    	#
#  To execute this script "bash WRF4.4_Install.bash"	#
#########################################################
WRFversion="4.4"
type="ARW"
echo "Welcome! This Script will install the WRF${WRFversion}-${type}"
echo "Installation may take several hours and it takes 52 GB storage. Be sure that you have enough time and storage."
#########################################################
#	Controls					#
#########################################################
osbit=$(uname -m)
if [ "$osbit" = "x86_64" ]; then
        echo "64 bit operating system is used"
else
        echo "Sorry! This script was written for 64 bit operating systems."
exit
fi
########
packagemanagement=$(which apt)
if [ -n "$packagemanagement" ]; then
        echo "Operating system uses apt packagemanagement"
else
        echo "Sorry! This script is written for the operating systems which uses apt packagemanagement. Please try this script with debian based operating systems, such as, Ubuntu, Linux Mint, Debian, Pardus etc."
#Tested on Ubuntu 20.04
exit
fi

#########################################################
#   Installing neccesary packages                       #
#########################################################

echo "Please enter your sudo password, so necessary packages can be installed."
sudo apt-get update
mpich_repoversion=$(apt-cache policy mpich | grep Candidate | cut -d ':' -f 2 | cut -d '-' -f 1 | cut -c2)
if [ "$mpich_repoversion" -ge 4 ]; then
mpirun_packages="libopenmpi-dev libhdf5-openmpi-dev"
else
mpirun_packages="mpich libhdf5-mpich-dev"
fi
sudo apt-get install -y build-essential csh gfortran m4 curl perl ${mpirun_packages} libpng-dev netcdf-bin libnetcdff-dev ${extra_packages}

package4checks="build-essential csh gfortran m4 curl perl ${mpirun_packages} libpng-dev netcdf-bin libnetcdff-dev ${extra_packages}"
for packagecheck in ${package4checks}; do
 packagechecked=$(dpkg-query --show --showformat='${db:Status-Status}\n' $packagecheck | grep not-installed)
 if [ "$packagechecked" = "not-installed" ]; then
        echo $packagecheck "$packagechecked"
     packagesnotinstalled=yes
 fi
done
if [ "$packagesnotinstalled" = "yes" ]; then
        echo "Some packages were not installed, please re-run the script and enter your root password, when it is requested."
exit
fi
#########################################
cd ~
mkdir Build_WRF
cd Build_WRF
mkdir LIBRARIES
cd LIBRARIES
echo "" >> ~/.bashrc
bashrc_exports=("#WRF Variables" "export DIR=$(pwd)" "export CC=gcc" "export CXX=g++" "export FC=gfortran" "export FCFLAGS=-m64" "export F77=gfortran" "export FFLAGS=-m64"
		"export NETCDF=/usr" "export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/serial" "export LDFLAGS="\""-L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -L/usr/lib"\""" 
		"export CPPFLAGS="\""-I/usr/include/hdf5/serial/ -I/usr/include"\""" "export LD_LIBRARY_PATH=/usr/lib")
for bashrc_export in "${bashrc_exports[@]}" ; do
[[ -z $(grep "${bashrc_export}" ~/.bashrc) ]] && echo "${bashrc_export}" >> ~/.bashrc
done
DIR=$(pwd)
export CC=gcc
export CXX=g++
export FC=gfortran
export FCFLAGS=-m64
export F77=gfortran
export FFLAGS=-m64
export NETCDF=/usr
export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/serial
export LDFLAGS="-L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -L/usr/lib"
export CPPFLAGS="-I/usr/include/hdf5/serial/ -I/usr/include"
export LD_LIBRARY_PATH=/usr/lib

##########################################
#	Jasper Installation		#
#########################################
[ -d "jasper-1.900.1" ] && mv jasper-1.900.1 jasper-1.900.1-old
[ -f "jasper-1.900.1.tar.gz" ] && mv jasper-1.900.1.tar.gz jasper-1.900.1.tar.gz-old
wget http://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz
tar -zxvf jasper-1.900.1.tar.gz
cd jasper-1.900.1/
./configure --prefix=$DIR/grib2
make
make install
echo "export JASPERLIB=$DIR/grib2/lib" >> ~/.bashrc
echo "export JASPERINC=$DIR/grib2/include" >> ~/.bashrc
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include
cd ..
#########################################
#	WRF Installation		#
#########################################
cd ..
[ -d "WRFV${WRFversion}" ] && mv WRFV${WRFversion} WRFV${WRFversion}-old
[ -f "v${WRFversion}.tar.gz" ] && mv v${WRFversion}.tar.gz v${WRFversion}.tar.gz-old
wget https://github.com/wrf-model/WRF/releases/download/v${WRFversion}/v${WRFversion}.tar.gz
mv v${WRFversion}.tar.gz WRFV${WRFversion}.tar.gz
tar -zxvf WRFV${WRFversion}.tar.gz
cd WRFV${WRFversion}
sed -i 's#$NETCDF/lib#$NETCDF/lib/x86_64-linux-gnu#g' configure
cd arch
cp Config.pl Config.pl_backup
sed -i '428s/.*/  $response = 34 ;/' Config.pl
sed -i '869s/.*/  $response = 1 ;/' Config.pl
cd ..
./configure
sed -i 's#-L/usr/lib -lnetcdff -lnetcdf#-L/usr/lib/x86_64-linux-gnu -lnetcdff -lnetcdf#g' configure.wrf
gfortversion=$(gfortran -dumpversion | cut -c1)
if [ "$gfortversion" -lt 8 ] && [ "$gfortversion" -ge 6 ]; then
sed -i '/-DBUILD_RRTMG_FAST=1/d' configure.wrf
fi
logsave compile.log ./compile em_real
cd arch
cp Config.pl_backup Config.pl
cd ..
if [ -n "$(grep "Problems building executables, look for errors in the build log" compile.log)" ]; then
        echo "Sorry, There were some errors while installing WRF."
        echo "Please create new issue for the problem, https://github.com/bakamotokatas/WRF-Install-Script/issues"
        exit
fi
cd ..
[ -d "WRF-${WRFversion}-${type}" ] && mv WRF-${WRFversion}-${type} WRF-${WRFversion}-${type}-old
mv WRFV${WRFversion} WRF-${WRFversion}-${type}
#########################################
#	WPS Installation		#
#########################################
WPSversion="4.4"
[ -d "WPS-${WPSversion}" ] && mv WPS-${WPSversion} WPS-${WPSversion}-old
[ -f "v${WPSversion}.tar.gz" ] && mv v${WPSversion}.tar.gz v${WPSversion}.tar.gz-old
wget https://github.com/wrf-model/WPS/archive/v${WPSversion}.tar.gz
mv v${WPSversion}.tar.gz WPSV${WPSversion}.TAR.gz
tar -zxvf WPSV${WPSversion}.TAR.gz
cd WPS-${WPSversion}
cd arch
cp Config.pl Config.pl_backup
sed -i '154s/.*/  $response = 3 ;/' Config.pl
cd ..
./clean
sed -i '141s/.*/    NETCDFF="-lnetcdff"/' configure
sed -i "173s/.*/standard_wrf_dirs=\"WRF-${WRFversion}-${type} WRF WRF-4.0.3 WRF-4.0.2 WRF-4.0.1 WRF-4.0 WRFV3\"/" configure
./configure
logsave compile.log ./compile
sed -i "s# geog_data_path.*# geog_data_path = '../WPS_GEOG/'#" namelist.wps
cd arch
cp Config.pl_backup Config.pl
cd ..
cd ..
echo "Installation has completed"
exec bash
exit
