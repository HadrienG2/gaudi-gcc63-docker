FROM gcc:6.2
LABEL Description="GCC 6.2-based Gaudi build environment" Version="0.1"
CMD bash


# === SYSTEM SETUP ===

# Update the host system
RUN apt update && apt upgrade --yes

# Install ROOT's build prerequisites (yes, they are ridiculous)
RUN apt install --yes dpkg-dev libxpm-dev libxft-dev libglu1-mesa-dev          \
                      libglew-dev libftgl-dev libfftw3-dev libcfitsio-dev      \
                      graphviz-dev libavahi-compat-libdnssd-dev libldap2-dev   \
                      python-dev libgsl0-dev libqt4-dev libgl2ps-dev           \
                      liblz4-dev liblz4-tool


# === INSTALL CMAKE ===

# Dowload and extract CMake v3.11.0
RUN curl https://cmake.org/files/v3.11/cmake-3.11.0.tar.gz | tar -xz

# Build and install CMake
RUN cd cmake-3.11.0 && mkdir build && cd build                                 \
    && ../bootstrap && make -j8 && make install

# Get rid of the CMake build directory
RUN rm -rf cmake-3.11.0


# === INSTALL ROOT ===

# Clone the desired ROOT version
RUN git clone --branch=v6-12-06 --single-branch                                \
    https://github.com/root-project/root.git ROOT

# Configure a reasonably minimal build of ROOT
RUN cd ROOT && mkdir build-dir && cd build-dir                                 \
    && cmake -Dbuiltin_ftgl=OFF -Dbuiltin_glew=OFF -Dbuiltin_lz4=OFF           \
             -Dbuiltin_tbb=ON -Dcastor=OFF -Dcxx14=ON -Ddavix=OFF              \
             -Dfail-on-missing=ON -Dgfal=OFF -Dgnuinstall=ON -Dhttp=OFF        \
             -Dmysql=OFF -Doracle=OFF -Dpgsql=OFF -Dpythia6=OFF -Dpythia8=OFF  \
             -Droot7=ON -Dssl=OFF -Dxrootd=OFF ..

# Build and install ROOT
RUN cd ROOT/build-dir && make -j8 && make install

# Set up the environment for running ROOT
ENV LD_LIBRARY_PATH /usr/local/lib/root/:${LD_LIBRARY_PATH}

# Check that the ROOT install works
RUN root -b -q -e "(6*7)-(6*7)"

# Get rid of the ROOT build directory to save up space
RUN rm -rf ROOT


# === TODO: Install other Gaudi build dependencies ===



# Clean up the system when we are done
RUN apt-get clean