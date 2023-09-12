# Download and unpack sources
FROM ubuntu:22.04 as download_stage

RUN apt-get update \
    && apt-get install -y wget unzip
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

# Build sources
FROM ubuntu:22.04 as build_stage
COPY --from=download_stage /tmp /tmp
RUN apt-get update && apt-get install -y \
    gcc gfortran g++ libtool automake autoconf make m4 grads \
    default-jre csh


ENV DIR=/cryowrf
ENV MAKEFLAGS=-j12
ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran
ENV F77=gfortran

RUN mkdir -p $DIR

# Build zlib
WORKDIR /tmp/zlib-1.2.13
RUN ./configure --prefix=$DIR && make && make install

# Build hdf5
WORKDIR /tmp/hdf5-1.10.5
RUN ./configure --prefix=$DIR --with-zlib=$DIR \
    --enable-hl --enable-fortran \
    && make && make install

ENV HDF5=$DIR
ENV LD_LIBRARY_PATH=$DIR/lib

# Build netcdf-c
WORKDIR /tmp/netcdf-c-4.9.0
ENV CPPFLAGS=-I$DIR/include
ENV LDFLAGS=-L$DIR/lib
RUN ./configure --prefix=$DIR --disable-dap --disable-testsets \
    && make check \
    && make install

# Build netcdf-fortran
ENV CPPFLAGS=-I$DIR/include
ENV LDFLAGS=-L$DIR/lib
ENV LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lz"

WORKDIR /tmp/netcdf-fortran-4.6.0
RUN ./configure --prefix=$DIR --disable-shared && make check && make install

# Build mpich
# WORKDIR /tmp/mpich-3.3.1
# RUN ./configure --prefix=$DIR && make && make install

RUN apt-get install -y mpich

# Update PATH
ENV PATH=$DIR/bin:$PATH

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
RUN apt-get install -y cmake csh m4 gfortran git wget
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
# WORKDIR /tmp/CRYOWRF/snpack_for_wrf
# RUN mkdir -p /tmp/CRYOWRF/snpack_for_wrf/snow_libs
ENV WRF_SRC_ROOT_DIR=/tmp/CRYOWRF/WRF
# ENV LD_LIBRARY_PATH=/home/wever/netcdf/usr/lib:/home/wever/mpich/usr/lib/:/home/wever/jasper-1.900.29/usr/lib/:$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/

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

ENV NETCDF4=1
ENV WRFIO_NCD_LARGE_FILE_SUPPORT=1
ENV NETCDF=$DIR
ENV NETCDF_classic=0
ENV WRFIO_NCD_LARGE_FILE_SUPPORT=1
#export WRFIO_NCD_NO_LARGE_FILE_SUPPORT=0

# MPI settings
ENV MPI_ROOT=/cryowrf/mpich/usr/

ENV SNOWLIBS=/crywrf/snpack_for_wrf
# export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/mpich #/usr/lib/x86_64-linux-gnu/

# export PATH=${HOME}/mpich/usr/bin/:${PATH}
# export LD_LIBRARY_PATH=${HOME}/mpich/usr/lib/:${LD_LIBRARY_PATH}


# RUN bash ./compiler_snow_libs.sh

# Build meteoio
WORKDIR /tmp/CRYOWRF/snpack_for_wrf/meteoio/build
RUN cmake -DCMAKE_INSTALL_PREFIX=/tmp/CRYOWRF/snpack_for_wrf/snow_libs .. && make -j9 && make install

ENV SNOWLIBS=/tmp/CRYOWRF/snpack_for_wrf/snow_libs

# Build snowpack
WORKDIR /tmp/CRYOWRF/snpack_for_wrf/snowpack/build
RUN cmake -DMETEOIO_INCLUDE_DIR=/tmp/CRYOWRF/snpack_for_wrf/snow_libs/include -DMETEOIO_LIBRARY=/tmp/CRYOWRF/snpack_for_wrf/snow_libs/lib/libmeteoio.a -DCMAKE_INSTALL_PREFIX=/tmp/CRYOWRF/snpack_for_wrf/snow_libs .. && make -j9 && make install

# Build coupler
WORKDIR /tmp/CRYOWRF/snpack_for_wrf/main_coupler
RUN gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 coupler_mod.f90 -I/tmp/CRYOWRF/snpack_for_wrf/snow_libs/include
RUN gfortran -c -O3 -g -fbacktrace -ffree-line-length-512 funcs.f90 -I/tmp/CRYOWRF/snpack_for_wrf/snow_libs/include
RUN g++ -c -O3 -g coupler_capi.cpp -I../snow_libs/include
RUN g++ -c -O3 -g Coupler.cpp -I../snow_libs/include
RUN make
RUN mv libcoupler.a /tmp/CRYOWRF/snpack_for_wrf/snow_libs/lib
RUN mkdir -p /tmp/CRYOWRF/snpack_for_wrf/snow_libs/include/coupler
RUN mv *.mod /tmp/CRYOWRF/snpack_for_wrf/snow_libs/include/coupler
RUN make clean


# ENV SNOWLIBS=/tmp/CRYOWRF/snpack_for_wrf

# FROM gcc:4.8.5 as wrf_stage
# FROM gcc:4.9 as wrf_stage
# Following WRF instructions https://und.edu/research/computational-research-center/tutorials/program-tutorials/install_wrf.html
# COPY --from=build_stage /tmp/CRYOWRF /tmp/CRYOWRF

# ENV HOME=/tmp
# ENV EM_CORE=1
# ENV NMM_CORE=0
# ENV WRF_CHEM=1
# ENV WRF_KPP=1
# ENV NETCDF=$HOME/netcdf
# ENV YACC='/share/apps/byacc/bin/yacc -d'
# ENV FLEX=/usr/bin
# ENV FLEX_LIB_DIR=/usr/lib64
# ENV KPP_HOME=$HOME/WRFV3/chem/KPP/kpp/kpp-2.1
# RUN echo "export PATH=$NETCDF/bin:$KPP_HOME/bin:$PATH" >> ~/.bashrc
# ENV SED=/bin/sed
# ENV WRFIO_NCD_LARGE_FILE_SUPPORT=1
# RUN echo "export WRF_SRC_ROOT_DIR=$HOME/WRFV3" >> ~/.bashrc
# ENV CC=gcc
# ENV CXX=g++
# ENV FC=gfortran
# ENV F77=gfortran
# ENV FFLAGS=–m64
# ENV FCFLAGS=–m64

# # Get NetCDF 4.4.0
# WORKDIR /tmp
# RUN wget --no-check-certificate https://github.com/Unidata/netcdf-c/archive/v4.4.0.tar.gz
# RUN tar -zxvf v4.4.0.tar.gz
# WORKDIR /tmp/netcdf-c-4.4.0
# # RUN ln -s /bin/sed /usr/bin/sed
# RUN ./configure --prefix=$NETCDF --disable-dap --disable-netcdf-4 && make check install

# FROM build_stage as netcdf_fortran

# FROM gcc:4.9 as gcc49
# COPY --from=wrf_stage /tmp /tmp
# Get NetCDF-Fortran 4.4.3
# WORKDIR /tmp
# RUN wget --no-check-certificate https://github.com/Unidata/netcdf-fortran/archive/v4.4.3.tar.gz
# RUN tar -zxvf v4.4.3.tar.gz

# ENV NCDIR=$NETCDF
# ENV NFDIR=$NETCDF
# ENV CC=/usr/local/bin/gcc
# # ENV FC=/usr/local/bin/gfortran
# RUN echo "export LD_LIBRARY_PATH=$NCDIR/lib:$LD_LIBRARY_PATH" >> ~/.bashrc

# WORKDIR /tmp/netcdf-fortran-4.4.3
# RUN which gfortran
# COPY --from=gcc:4.9 /usr/local/bin/gfortran /usr/local/bin/gfortran
# ENV FC=/usr/local/bin/gfortran
# ENV F77=/usr/local/bin/gfortran
# RUN ln -s /usr/local/bin/gfortran /usr/bin/gfortran
# RUN ls /usr/local/bin
# RUN ls /usr/bin
# find / -name 'gfortran'
# RUN ./configure --prefix=$NFDIR && make install

########
WORKDIR /tmp/CRYOWRF/WRF

# WORKDIR /
# RUN cp -r /tmp/CRYOWRF /
# WORKDIR /CRYOWRF/WRF
# COPY ./compile /tmp/CRYOWRF/WRF/compile
ENV SNOWLIBS=/tmp/CRYOWRF/snpack_for_wrf

RUN apt-get install -y tcsh gfortran-9
# RUN echo "alias ftn='mpif90'" >> ~/.bashrc
RUN echo "alias ftn='gfortran-9'" >> ~/.bashrc
RUN echo 35 | ./configure
RUN sed -i '131c\SFC             =       gfortran-9' configure.wrf
RUN sed -i '134c\DM_FC           =       gfortran-9' configure.wrf
RUN sed -i '162c\CPP             =      /usr/bin/cpp-9 -P -nostdinc' configure.wrf
RUN sed -i '162c\CPP             =      /usr/bin/cpp-9 -P -nostdinc' configure.wrf
RUN sed -i '162c\CPP             =      /usr/bin/cpp-9 -P -nostdinc' configure.wrf

RUN tcsh ./compile -j 12 em_real


ENV WRF_DIR=/tmp/CRYOWRF/WRF
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
