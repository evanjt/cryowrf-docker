# Download and unpack sources
FROM ubuntu:22.04 as download_stage

RUN apt-get update \
    && apt-get install -y wget unzip gcc gfortran g++ libtool automake autoconf make m4 grads \
    default-jre csh git cmake

WORKDIR /tmp

RUN wget -c http://zlib.net/fossils/zlib-1.2.13.tar.gz
RUN wget -c https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.5/src/hdf5-1.10.5.tar.gz
RUN wget -c https://downloads.unidata.ucar.edu/netcdf-c/4.9.0/netcdf-c-4.9.0.tar.gz
RUN wget -c https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.0/netcdf-fortran-4.6.0.tar.gz
RUN wget -c http://www.mpich.org/static/downloads/3.3.1/mpich-3.3.1.tar.gz
RUN wget -c https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz
RUN wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-1.900.1.zip

RUN tar -zxvf zlib-1.2.13.tar.gz
RUN tar -zxvf hdf5-1.10.5.tar.gz
RUN tar -zxvf netcdf-c-4.9.0.tar.gz
RUN tar -zxvf netcdf-fortran-4.6.0.tar.gz
RUN tar -zxvf mpich-3.3.1.tar.gz
RUN tar -zxvf libpng-1.6.37.tar.gz
RUN unzip jasper-1.900.1.zip
RUN rm *.tar.gz *.zip

RUN echo "export MAKEFLAGS=-j12" >> ~/.bashrc

# Build sources

ENV DIR=/cryowrf
RUN mkdir -p $DIR

ENV CC=gcc
ENV CXX=g++
ENV FC="gfortran -fallow-argument-mismatch -fallow-invalid-boz"
ENV F77="gfortran -fallow-argument-mismatch -fallow-invalid-boz"
ENV FFLAGS="-m64 -fallow-argument-mismatch -fallow-invalid-boz"
ENV FCFLAGS="-m64 -fallow-argument-mismatch -fallow-invalid-boz"

ENV WRF_EM_CORE=1
ENV WRF_NMM_CORE=0
ENV WRF_DA_CORE=0
ENV WRF_CHEM=0
ENV WRF_KPP=0

ENV WRFIO_NCD_LARGE_FILE_SUPPORT=1
ENV NETCDF4=1
ENV NETCDF=$DIR
ENV NETCDF_classic=0

# Build zlib
WORKDIR /tmp/zlib-1.2.13
RUN ./configure --prefix=$DIR && make && make install

# Build hdf5
WORKDIR /tmp/hdf5-1.10.5
RUN ./configure --prefix=$DIR --with-zlib=$DIR \
    --enable-hl --enable-fortran \
    && make && make install

ENV HDF5=$DIR
RUN echo "export LD_LIBRARY_PATH=$DIR/lib:$LD_LIBRARY_PATH" >> ~/.bashrc

RUN apt-get install -y build-essential libc6-dev
# Build netcdf-c
ENV CPPFLAGS=-I$DIR/include
ENV LDFLAGS=-L$DIR/lib
# ENV LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lz"

WORKDIR /tmp/netcdf-c-4.9.0
RUN ./configure --prefix=$DIR --disable-dap --disable-testsets --disable-hdf5 \
    && make check \
    && make install

# Build netcdf-fortran
WORKDIR /tmp/netcdf-fortran-4.6.0
RUN ./configure --prefix=$DIR --disable-shared && make check && make install

# Build mpich
WORKDIR /tmp/mpich-3.3.1
RUN ./configure --prefix=$DIR && make && make install

# RUN apt-get install -y mpich

# Update PATH
# ENV PATH=$DIR/bin:$PATH
RUN echo "export PATH=$DIR/bin:$PATH" >> ~/.bashrc
RUN echo $PATH

# Build libpng
ENV LDFLAGS=-L$DIR/lib
ENV CPPFLAGS=-I$DIR/include
WORKDIR /tmp/libpng-1.6.37
RUN ./configure --prefix=$DIR && make && make install

# Build jasper
WORKDIR /tmp/jasper-1.900.1
RUN autoreconf -i
RUN ./configure --prefix=$DIR && make && make install

ENV JASPERLIB=$DIR/lib
ENV JASPERINC=$DIR/include

#CRYOWRF
WORKDIR /tmp

#
# RUN wget https://src.fedoraproject.org/lookaside/pkgs/netcdf/netcdf-4.1.3.tar.gz/46a40e1405df19d8cc6ddac16704b05f/netcdf-4.1.3.tar.gz
# RUN tar -xvzf netcdf-4.1.3.tar.gz
# WORKDIR /tmp/netcdf-4.1.3
# RUN ./configure --disable-dap --disable-netcdf-4 --disable-shared --prefix=$DIR && make install
#
# # mpich
# RUN wget https://www.mpich.org/static/downloads/3.0.4/mpich-3.0.4.tar.gz
# RUN tar -xvzf mpich-3.0.4.tar.gz
# WORKDIR /tmp/mpich-3.0.4
# RUN ./configure --prefix=$DIR && make && make install

ENV WRF_EM_CORE=1
ENV WRF_NMM_CORE=0
ENV WRF_DA_CORE=0
ENV WRF_CHEM=0
ENV WRF_KPP=0
ENV WRFIO_NCD_LARGE_FILE_SUPPORT=1
ENV NETCDF_classic=1

WORKDIR /tmp
RUN git clone https://gitlabext.wsl.ch/atmospheric-models/CRYOWRF.git
WORKDIR /tmp/CRYOWRF
RUN git checkout v1.0
# WORKDIR $SNOWLIBS
# RUN mkdir -p $SNOWLIBS/snow_libs
ENV WRF_SRC_ROOT_DIR=/tmp/CRYOWRF/WRF
# ENV LD_LIBRARY_PATH=/home/wever/netcdf/usr/lib:/home/wever/mpich/usr/lib/:/home/wever/jasper-1.900.29/usr/lib/:$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/
RUN echo "export LD_LIBRARY_PATH=/home/wever/netcdf/usr/lib:/home/wever/mpich/usr/lib/:/home/wever/jasper-1.900.29/usr/lib/:$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/" >> ~/.bashrc


# MPI settings
# ENV MPI_ROOT=/cryowrf/mpich/usr/

ENV SNOWPACK_FOR_WRF_DIR=/tmp/CRYOWRF/snpack_for_wrf
# export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/mpich #/usr/lib/x86_64-linux-gnu/

# export PATH=${HOME}/mpich/usr/bin/:${PATH}
# export LD_LIBRARY_PATH=${HOME}/mpich/usr/lib/:${LD_LIBRARY_PATH}


# RUN bash ./compiler_snow_libs.sh

# Build meteoio
ENV SNOWLIBS=$SNOWPACK_FOR_WRF_DIR/snow_libs

WORKDIR $SNOWPACK_FOR_WRF_DIR/meteoio/build
RUN cmake -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. && make -j9 && make install

# Build snowpack
WORKDIR $SNOWPACK_FOR_WRF_DIR/snowpack/build
RUN cmake -DMETEOIO_INCLUDE_DIR=$SNOWLIBS/include -DMETEOIO_LIBRARY=$SNOWLIBS/lib/libmeteoio.a -DCMAKE_INSTALL_PREFIX=$SNOWLIBS .. && make -j9 && make install

# Build coupler
WORKDIR $SNOWPACK_FOR_WRF_DIR/main_coupler
RUN gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 coupler_mod.f90 -I$SNOWLIBS/include
RUN gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 funcs.f90 -I$SNOWLIBS/include
RUN g++ -c -O3 -g coupler_capi.cpp -I$SNOWLIBS/include
RUN g++ -c -O3 -g Coupler.cpp -I$SNOWLIBS/include
RUN make
RUN mv libcoupler.a $SNOWLIBS/lib
RUN mkdir -p $SNOWLIBS/include/coupler
RUN mv *.mod $SNOWLIBS/include/coupler
RUN make clean

ENV SNOWLIBS=$SNOWPACK_FOR_WRF_DIR
ENV WRF_DIR=/tmp/CRYOWRF/WRF
WORKDIR $WRF_DIR

RUN apt-get install -y tcsh
RUN echo "alias ftn='mpif90'" >> ~/.bashrc
# RUN echo "alias ftn='gfortran'" >> ~/.bashrc

ENV WRFPLUSPATH=$WRF_DIR

RUN echo 35 | ./configure
# RUN sed -i '131c\SFC             =       gfortran -fallow-argument-mismatch -fallow-invalid-boz' configure.wrf
# RUN sed -i '134c\DM_FC           =       mpif90 -fallow-argument-mismatch -fallow-invalid-boz' configure.wrf
# RUN sed -i '162c\CPP             =      /usr/bin/cpp -P -nostdinc' configure.wrf
# RUN sh -c "sed -i '238c\WRFPLUSPATH        =      $WRFPLUSPATH' configure.wrf"
RUN tcsh ./compile em_real -j 8



WORKDIR /tmp/CRYOWRF/WPS-4.2

RUN echo 2 | ./configure
# RUN sed -i '63c\SFC             =     mpif90' configure.wps
RUN echo gcc --version
RUN tcsh ./compile


# RUN apt-get install -y wget
# RUN wget -c https://github.com/wrf-model/WRF/archive/v4.1.2.tar.gz
# RUN tar -xvzf v4.1.2.tar.gz
# WORKDIR /tmp/WRF-4.1.2
# RUN ./clean
# RUN ./configure # 34, 1 for gfortran and distributed memory
# RUN ./compile em_real

# export WRF_DIR=$HOME/WRF/WRF-4.1.2

# ## WPSV4.1
# cd $HOME/WRF/Downloads
# wget -c https://github.com/wrf-model/WPS/archive/v4.1.tar.gz
# tar -xvzf v4.1.tar.gz -C $HOME/WRF
# cd $HOME/WRF/WPS-4.1
# ./configure #3
# ./compile
