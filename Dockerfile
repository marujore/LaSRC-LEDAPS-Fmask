FROM ubuntu:18.04
LABEL maintainer="Rennan Marujo <rennanmarujo@gmail.com>"

USER root

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        'gcc' \
        'wget' \
        'make' \
        'curl' \
        'gdal-bin' \
        'python' \
        'python-numpy' \
        'python-gdal' \
        'python-requests' \
        'libtiff-dev' \
        'libjpeg-dev' \
        'libxml2-dev' \
        'libgeotiff-dev' \
        'libhdf5-dev' \
        'libnetcdf-dev' \
        'libidn11-dev' \
        'zlib1g' \
        'zlib1g-dev' \
        'liblzma-dev' \
        'libopenjp2-tools' \
        'unzip' \
        'libxmu6' \
        'openjdk-11-jdk' \
        'xserver-xorg' \
        'gfortran' \
        'git' \
        'nano' \
        'bison' \
        'flex'


#Build HDF4
WORKDIR /tmp
RUN wget https://support.hdfgroup.org/ftp/HDF/releases/HDF4.2.15/src/hdf-4.2.15.tar.gz
RUN tar zxf hdf-4.2.15.tar.gz
RUN cd hdf-4.2.15 && \
    ./configure --prefix=/usr --disable-fortran --enable-production --enable-shared --disable-netcdf && \
    make -j16 && \
    make -j16 install && \
    make clean


#Build HDF-EOS2
WORKDIR /tmp
RUN curl https://observer.gsfc.nasa.gov/ftp/edhs/hdfeos/latest_release/HDF-EOS2.20v1.00.tar.Z -o /tmp/hdfeos.tar.Z
RUN tar xzf /tmp/hdfeos.tar.Z -C /opt
WORKDIR /opt/hdfeos
RUN ./configure CC=/usr/bin/h4cc --prefix=/opt/hdfeos/build && \
    make -j 4 && \
    make install && \
    make clean && \
    ls /opt/hdfeos/build


#Build HDF-EOS5
WORKDIR /tmp
RUN curl https://observer.gsfc.nasa.gov/ftp/edhs/hdfeos5/latest_release/HDF-EOS5.1.16.tar.Z -o /tmp/hdfeos5.tar.Z
RUN tar xzf /tmp/hdfeos5.tar.Z -C /opt
WORKDIR /opt/hdfeos5
RUN ./configure CC=/usr/bin/h5cc --prefix=/opt/hdfeos5/build --with-szlib=/usr/ && \
   make -j 4 && \
   make install && \
   make clean && \
   ls /opt/hdfeos5/build


# environment
ENV HDFEOS_GCTPINC=/opt/hdfeos/gctp/include
ENV HDFEOS_GCTPLIB=/opt/hdfeos/build/lib
ENV TIFFINC=/usr/include/x86_64-linux-gnu
ENV TIFFLIB=/usr/lib/x86_64-linux-gnu
ENV GEOTIFF_INC=/usr/include/geotiff
ENV GEOTIFF_LIB=/usr/lib/x86_64-linux-gnu
ENV HDFINC=/usr/include/hdf
ENV HDFLIB=/usr/lib/libdf.so
ENV HDF5INC=/usr/include/hdf5/serial
ENV HDF5LIB=/usr/lib/x86_64-linux-gnu/hdf5/serial
ENV HDFEOS_INC=/opt/hdfeos/include
ENV HDFEOS_LIB=/opt/hdfeos/build/lib
ENV HDFEOS5_LIB=/opt/hdfeos5/build/lib
ENV HDFEOS5_INC=/opt/hdfeos5/include
ENV NCDF4INC=/usr/include
ENV NCDF4LIB=/usr/lib/x86_64-linux-gnu
ENV JPEGINC=/usr/include
ENV JPEGLIB=/usr/lib/x86_64-linux-gnu
ENV XML2INC=/usr/include/libxml2
ENV XML2LIB=/usr/lib/x86_64-linux-gnu
ENV JBIGINC=/usr/include
ENV JBIGLIB=/usr/lib/x86_64-linux-gnu
ENV ZLIBINC=/usr/include
ENV ZLIBLIB=/usr/lib/x86_64-linux-gnu
ENV SZIPINC=/usr/include
ENV SZIPLIB=/usr/lib/x86_64-linux-gnu
ENV CURLINC=/usr/include/curl
ENV CURLLIB=/usr/lib/x86_64-linux-gnu
ENV LZMAINC=/usr/include/lzma
ENV LZMALIB=/usr/lib/x86_64-linux-gnu
ENV IDNINC=/usr/include
ENV IDNLIB=/usr/lib/x86_64-linux-gnu
ENV ESPAINC=/opt/espa-product-formatter/raw_binary/include
ENV ESPALIB=/opt/espa-product-formatter/raw_binary/lib


# product formatter
WORKDIR /tmp
#RUN curl -L https://github.com/USGS-EROS/espa-product-formatter/archive/product_formatter_v1.19.0.tar.gz -o /tmp/product_formatter.tar.gz && \
RUN curl -L https://github.com/brazil-data-cube/espa-product-formatter/archive/product_formatter_v1.19.0.tar.gz -o /tmp/product_formatter.tar.gz && \
   tar xzf /tmp/product_formatter.tar.gz && \
   mv espa-product-formatter-product_formatter_v1.19.0 /opt/espa-product-formatter && \
   rm /tmp/product_formatter.tar.gz

ENV PREFIX=/opt/espa-product-formatter/build

WORKDIR /opt/espa-product-formatter
RUN make && \
   make install && \
   ls -l $PREFIX


# surface reflectance LaSRC
WORKDIR /tmp
# RUN curl -L https://github.com/USGS-EROS/espa-surface-reflectance/archive/master.tar.gz -o /tmp/lasrc.tar.gz && \
# RUN curl -L https://github.com/USGS-EROS/espa-surface-reflectance/archive/dev_lasrc_v2.0.1.tar.gz -o /tmp/lasrc.tar.gz && \
RUN curl -L https://github.com/brazil-data-cube/espa-surface-reflectance/archive/dev_lasrc_v2.0.1.tar.gz -o /tmp/lasrc.tar.gz && \
    tar xzf /tmp/lasrc.tar.gz && \
    # mv espa-surface-reflectance-master /opt/espa-surface-reflectance && \
    mv espa-surface-reflectance-dev_lasrc_v2.0.1 /opt/espa-surface-reflectance && \
    rm /tmp/lasrc.tar.gz

ENV PREFIX=/opt/espa-surface-reflectance/build

WORKDIR /opt/espa-surface-reflectance/lasrc
RUN make && \
    make install && \
    make clean && \
    ls -l $PREFIX

RUN make all-lasrc-aux && \
    make install-lasrc-aux && \
    make clean-lasrc-aux && \
    ls -l $PREFIX

WORKDIR /opt/espa-surface-reflectance/scripts
RUN make && \
    make install && \
    make clean && \
    ls -l $PREFIX

ENV L8_AUX_DIR=/mnt/lasrc-aux
ENV LASRC_AUX_DIR=$L8_AUX_DIR
ENV ESPA_SCHEMA=/opt/espa-product-formatter/build/schema/espa_internal_metadata_v2_2.xsd
ENV PATH=/opt/espa-product-formatter/build/bin:/opt/espa-cloud-masking/build/bin:/opt/espa-surface-reflectance/build/bin:$PATH

# surface reflectance LEDAPS
WORKDIR /opt/espa-surface-reflectance/ledaps/ledapsSrc/src
RUN make && \
    make install
WORKDIR /opt/espa-surface-reflectance/ledaps/ledapsAncSrc
RUN make && \
    make install
RUN mkdir /usr/tmp
ENV PATH=/opt/espa-surface-reflectance/ledaps/ledapsSrc/scripts/:$PATH
ENV LEDAPS_AUX_DIR=/mnt/ledaps-aux/


# cloud masking FMASK 4
COPY Fmask_4_2_Linux.install .
RUN chmod +x Fmask_4_2_Linux.install && \
    ./Fmask_4_2_Linux.install -mode silent -agreeToLicense yes && \
    rm Fmask_4_2_Linux.install

ENV MCR_CACHE_ROOT="/tmp/mcr-cache"

WORKDIR /work

COPY run_lasrc_ledaps_fmask.sh /usr/local/bin/run_lasrc_ledaps_fmask.sh
RUN chmod +x /usr/local/bin/run_lasrc_ledaps_fmask.sh

ENTRYPOINT ["/usr/local/bin/run_lasrc_ledaps_fmask.sh"]
CMD ["--help"]

RUN apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*
