FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update \
    && apt-get install -y wget git sudo tzdata

ARG DIR=/tmp

ARG CC=gcc
ARG CXX=g++
ARG FC=gfortran
ARG FCFLAGS=-m64
ARG F77=gfortran
ARG FFLAGS=-m64
ARG NETCDF=/usr
ARG HDF5=/usr/lib/x86_64-linux-gnu/hdf5/serial
ARG LDFLAGS="-L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -L/usr/lib"
ARG CPPFLAGS="-I/usr/include/hdf5/serial/ -I/usr/include"
ARG LD_LIBRARY_PATH=/usr/lib

WORKDIR $DIR

RUN apt-get update && apt-get install -y build-essential csh gfortran m4 \
    curl perl libpng-dev netcdf-bin libnetcdff-dev cmake tcsh libopenmpi-dev \
    libhdf5-openmpi-dev

# Install Jasper
RUN wget https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz -O jasper-1.900.1.tar.gz
RUN tar -zxvf jasper-1.900.1.tar.gz
WORKDIR $DIR/jasper-1.900.1/
RUN ./configure --prefix=$DIR/grib2 && make && make install

RUN echo "export JASPERLIB=$DIR/grib2/lib" >> ~/.bashrc
RUN echo "export JASPERINC=$DIR/grib2/include" >> ~/.bashrc

ARG JASPERLIB=$DIR/grib2/lib
ARG JASPERINC=$DIR/grib2/include

# Copy CRYOWRF source code (change to repository when available)
WORKDIR $DIR

ARG SNOWLIBS=$DIR/snow_libs
ARG CRYOWRF_SRC=$DIR/CRYOWRF
RUN echo "export SNOWLIBS=$DIR/snow_libs" >> ~/.bashrc
RUN echo "export CRYOWRF_SRC=$DIR/CRYOWRF" >> ~/.bashrc

COPY ./CRYOWRF $CRYOWRF_SRC

## Install MeteoIO
WORKDIR $CRYOWRF_SRC/snpack_for_wrf/meteoio/build
RUN cmake -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. \
    && make -j9 && make install

# Build Snowpack
WORKDIR $CRYOWRF_SRC/snpack_for_wrf/snowpack/build
RUN cmake -DMETEOIO_INCLUDE_DIR=$SNOWLIBS/include \
    -DMETEOIO_LIBRARY=$SNOWLIBS/lib/libmeteoio.a \
    -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. \
    && make -j9 && make install

# Build Coupler
WORKDIR $CRYOWRF_SRC/snpack_for_wrf/main_coupler
RUN gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 coupler_mod.f90 -I$SNOWLIBS/include \
    && gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 funcs.f90 -I$SNOWLIBS/include \
    && g++ -c -O3 -g coupler_capi.cpp -I$SNOWLIBS/include \
    && g++ -c -O3 -g Coupler.cpp -I$SNOWLIBS/include \
    && make \
    && mv libcoupler.a $SNOWLIBS/lib \
    && mkdir -p $SNOWLIBS/include/coupler \
    && mv *.mod $SNOWLIBS/include/coupler \
    && make clean

# Build WRF
WORKDIR $CRYOWRF_SRC/WRF

RUN sed -i 's#$NETCDF/lib#$NETCDF/lib/x86_64-linux-gnu#g' configure
RUN echo 35 | ./configure
RUN sed -i 's#-L/usr/lib -lnetcdff -lnetcdf#-L/usr/lib/x86_64-linux-gnu -lnetcdff -lnetcdf#g' configure.wrf
RUN if [ $(gfortran -dumpversion | cut -c1) -lt 8 ] && [ $(gfortran -dumpversion | cut -c1) -ge 6 ]; then sed -i '/-DBUILD_RRTMG_FAST=1/d' configure.wrf ; fi
RUN tcsh ./compile -j 12 em_real


# Build WPS
WORKDIR $CRYOWRF_SRC/WPS

RUN echo 2 | ./configure
# RUN sed -i '63c\SFC             =     mpif90' configure.wps
# RUN echo gcc --version
RUN tcsh ./clean
RUN sed -i '163s/.*/    NETCDFF="-lnetcdff"/' configure
RUN sed -i "s/standard_wrf_dirs=.*/standard_wrf_dirs=\"WRF WRF-4.0.3 WRF-4.0.2 WRF-4.0.1 WRF-4.0 WRFV3\"/" configure
RUN echo 3 | ./configure
RUN tcsh ./compile
# RUN sed -i "s# geog_data_path.*# geog_data_path = '../WPS_GEOG/'#" namelist.wps


# RUN tcsh ./compile