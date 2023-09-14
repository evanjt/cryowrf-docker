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

COPY sources.sh $DIR
RUN chmod +x sources.sh
RUN bash ./sources.sh

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

## Install MeteoIO & Snowpack
# RUN mkdir -p $CRYOWRF_SRC/snpack_for_wrf/meteoio/build
WORKDIR $CRYOWRF_SRC/snpack_for_wrf/meteoio/build
RUN cmake -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. \
    && make -j9 && make install

# Build Snowpack
# mkdir -p $CRYOWRF_SRC/snpack_for_wrf/snowpack/build
WORKDIR $CRYOWRF_SRC/snpack_for_wrf/snowpack/build
RUN cmake -DMETEOIO_INCLUDE_DIR=$SNOWLIBS/include \
    -DMETEOIO_LIBRARY=$SNOWLIBS/lib/libmeteoio.a \
    -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. \
    && make -j9 && make install

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