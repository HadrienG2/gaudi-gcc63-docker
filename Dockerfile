FROM gcc:6.2
LABEL Description="GCC 6.2-based Gaudi build environment" Version="0.1"
CMD bash
SHELL ["/bin/bash", "-c"]


# === SYSTEM SETUP ===

# Setup an environment script (you can think of it as a non-interactive bashrc)
RUN touch /bash_env.sh && echo "source /bash_env.sh" >> /etc/profile
ENV BASH_ENV /bash_env.sh

# Update the host system
RUN apt-get update && apt-get upgrade --yes

# Install ROOT's build prerequisites (yes, they are ridiculous)
RUN apt-get install --yes dpkg-dev libxpm-dev libxft-dev libglu1-mesa-dev      \
                          libglew-dev libftgl-dev libfftw3-dev libcfitsio-dev  \
                          graphviz-dev libavahi-compat-libdnssd-dev            \
                          libldap2-dev python-dev libgsl0-dev libqt4-dev       \
                          libgl2ps-dev liblz4-dev liblz4-tool libblas-dev      \
                          python-numpy

# Install other Gaudi build prerequisites
RUN apt-get install --yes doxygen graphviz libboost-all-dev


# === INSTALL CMAKE ===

# Dowload and extract CMake v3.11.0
RUN curl https://cmake.org/files/v3.11/cmake-3.11.0.tar.gz | tar -xz

# Build and install CMake
RUN cd cmake-3.11.0 && mkdir build && cd build                                 \
    && ../bootstrap && make -j8 && make install

# Get rid of the CMake build directory
RUN rm -rf cmake-3.11.0


# === INSTALL INTEL TBB ===

# Clone TBB v2018u3
RUN git clone --branch=2018_U3 --single-branch https://github.com/01org/tbb.git

# Build TBB
RUN cd tbb && make -j8

# "Install" TBB (Yes, TBB has nothing like "make install". Ask Intel.)
RUN cd tbb                                                                     \
    && make info | tail -n 1 > tbb_prefix.env                                  \
    && source tbb_prefix.env                                                   \
    && ln -s build/${tbb_build_prefix}_release lib                             \
    && echo "source `pwd`/lib/tbbvars.sh" >> "$BASH_ENV"


# === INSTALL ROOT ===

# Clone the desired ROOT version
RUN git clone --branch=v6-12-06 --single-branch                                \
    https://github.com/root-project/root.git ROOT

# Configure a reasonably minimal build of ROOT
RUN cd ROOT && mkdir build-dir && cd build-dir                                 \
    && cmake -Dbuiltin_ftgl=OFF -Dbuiltin_glew=OFF -Dbuiltin_lz4=OFF           \
             -Dcastor=OFF -Dcxx14=ON -Ddavix=OFF -Dfail-on-missing=ON          \
             -Dgfal=OFF -Dgnuinstall=ON -Dhttp=OFF -Dmysql=OFF -Doracle=OFF    \
             -Dpgsql=OFF -Dpythia6=OFF -Dpythia8=OFF -Droot7=ON -Dssl=OFF      \
             -Dxrootd=OFF ..

# Build and install ROOT
RUN cd ROOT/build-dir && make -j8 && make install

# Set up the environment for running ROOT
ENV LD_LIBRARY_PATH /usr/local/lib/root/:${LD_LIBRARY_PATH}

# Check that the ROOT install works
RUN root -b -q -e "(6*7)-(6*7)"

# Get rid of the ROOT build directory to save up space
RUN rm -rf ROOT


# === INSTALL C++ GUIDELINE SUPPORT LIBRARY ===

# Download the GSL
RUN git clone https://github.com/Microsoft/GSL.git

# Build the GSL
RUN cd GSL && mkdir build && cd build                                          \
    && cmake .. && make -j8

# Check that the GSL build is working properly
RUN cd GSL/build && ctest -j8

# Install the GSL
RUN cd GSL/build && make install

# Get rid of the GSL build directory
RUN rm -rf GSL


# === INSTALL RANGE-V3

# Download the range-v3 library (v0.3.5)
RUN git clone --branch=0.3.5 --single-branch                                   \
              https://github.com/ericniebler/range-v3.git

# Build range-v3
RUN cd range-v3 && mkdir build && cd build                                     \
    && cmake .. && make -j8

# Check that the range-v3 build is working properly
RUN cd range-v3/build && ctest -j8

# Install range-v3
RUN cd range-v3/build && make install

# Get rid of the range-v3 build directory
RUN rm -rf range-v3


# === TODO: Install other Gaudi build dependencies ===

# === TODO: Download and attempt to build/test upstream Gaudi ===


# TODO: Clean up the system when we are done
# RUN apt-get clean