# Download and unpack sources
FROM ubuntu:18.04 as download_stage

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
FROM ubuntu:18.04 as build_stage
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
WORKDIR /tmp/mpich-3.3.1
RUN ./configure --prefix=$DIR && make && make install

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