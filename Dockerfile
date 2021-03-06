FROM debian:stretch
LABEL Description="GCC 6.3-based Gaudi build environment" Version="0.1"
CMD bash
SHELL ["/bin/bash", "-c"]


# === SYSTEM SETUP ===

# Build an environment setup script that works during docker build
#
# NOTE: This madness is necessary because docker build commands are run in a
#       shell which is neither a login shell nor an interactive shell, and
#       cannot be easily turned into either. Which means that there is no clean
#       entry point for running environment setup scripts in docker build.
#
RUN touch /setup_env.sh                                                        \
    && echo "unset BASH_ENV" > /root/bash_env.sh                               \
    && echo "source /setup_env.sh" >> /root/bash_env.sh                        \
    && echo "source /setup_env.sh" >> /root/.bashrc
ENV BASH_ENV="/root/bash_env.sh"                                               \
    SETUP_ENV="/setup_env.sh"

# Update the host system
RUN apt-get update && apt-get upgrade --yes

# Install ROOT's build prerequisites (yes, they are ridiculous)
RUN apt-get install --yes git dpkg-dev g++ gcc binutils libx11-dev libxpm-dev  \
                          libxft-dev libxext-dev gfortran libssl-dev           \
                          libpcre3-dev libglu1-mesa-dev libglew-dev            \
                          libftgl-dev default-libmysqlclient-dev libfftw3-dev  \
                          libcfitsio-dev graphviz-dev                          \
                          libavahi-compat-libdnssd-dev libldap2-dev python-dev \
                          libxml2-dev libkrb5-dev libgsl-dev libqt4-dev        \
                          libgl2ps-dev liblz4-dev liblz4-tool libblas-dev      \
                          python-numpy liblzma-dev libsqlite3-dev libjpeg-dev

# Install other build prerequisites
RUN apt-get install --yes doxygen graphviz libboost-all-dev libcppunit-dev gdb \
                          unzip libxerces-c-dev uuid-dev libunwind-dev         \
                          google-perftools libgoogle-perftools-dev             \
                          libjemalloc-dev libncurses5-dev ninja-build wget     \
                          python-nose python-networkx


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
RUN git clone --branch=2018_U3 --depth=1 https://github.com/01org/tbb.git

# Build TBB
RUN cd tbb && make -j8

# "Install" TBB (Yes, TBB has nothing like "make install". Ask Intel.)
RUN cd tbb                                                                     \
    && make info | tail -n 1 > tbb_prefix.env                                  \
    && source tbb_prefix.env                                                   \
    && ln -s build/${tbb_build_prefix}_release lib                             \
    && echo "source `pwd`/lib/tbbvars.sh" >> "$SETUP_ENV"


# === INSTALL ROOT ===

# Clone the desired ROOT version
RUN git clone --branch=v6-12-06 --depth=1                                      \
    https://github.com/root-project/root.git ROOT

# Configure a reasonably minimal build of ROOT
RUN cd ROOT && mkdir build-dir && cd build-dir                                 \
    && cmake -Dbuiltin_ftgl=OFF -Dbuiltin_glew=OFF -Dbuiltin_lz4=OFF           \
             -Dcastor=OFF -Dcxx14=ON -Ddavix=OFF -Dfail-on-missing=ON          \
             -Dgfal=OFF -Dgnuinstall=ON -Dhttp=OFF -Dmysql=OFF -Doracle=OFF    \
             -Dpgsql=OFF -Dpythia6=OFF -Dpythia8=OFF -Droot7=ON -Dssl=ON       \
             -Dxrootd=OFF -GNinja ..

# Build and install ROOT
RUN cd ROOT/build-dir && ninja && ninja install

# Prepare the environment for running ROOT
RUN echo "source /usr/local/bin/thisroot.sh" >> "$SETUP_ENV"

# Check that the ROOT install works
RUN root -b -q -e "(6*7)-(6*7)"

# Get rid of the ROOT build directory to save up space
RUN rm -rf ROOT


# === INSTALL C++ GUIDELINE SUPPORT LIBRARY ===

# Download the GSL
RUN git clone --depth=1 https://github.com/Microsoft/GSL.git

# Build the GSL
RUN cd GSL && mkdir build && cd build                                          \
    && cmake -GNinja .. && ninja

# Check that the GSL build is working properly
RUN cd GSL/build && ctest -j8

# Install the GSL
RUN cd GSL/build && ninja install

# Get rid of the GSL build directory
RUN rm -rf GSL


# === INSTALL RANGE-V3

# Download the range-v3 library (v0.3.5)
RUN git clone --branch=0.3.5 --depth=1                                         \
              https://github.com/ericniebler/range-v3.git

# Build range-v3
RUN cd range-v3 && mkdir build && cd build                                     \
    && cmake -GNinja .. && ninja

# Check that the range-v3 build is working properly
RUN cd range-v3/build && ctest -j8

# Install range-v3
RUN cd range-v3/build && ninja install

# Get rid of the range-v3 build directory
RUN rm -rf range-v3


# === INSTALL AIDA ===

# Download, extract and delete the AIDA package
RUN mkdir AIDA && cd AIDA                                                      \
    && wget                                                                    \
       ftp://ftp.slac.stanford.edu/software/freehep/AIDA/v3.2.1/aida-3.2.1.zip \
    && unzip -q aida-3.2.1.zip                                                 \
    && rm aida-3.2.1.zip

# Install the AIDA headers
RUN cp -r AIDA/src/cpp/AIDA /usr/include/

# Get rid of the rest of the package, we do not need it
RUN rm -rf AIDA


# === INSTALL CLHEP ===

# Download CLHEP
RUN git clone --branch=CLHEP_2_4_0_4 --depth=1                                 \
              https://gitlab.cern.ch/CLHEP/CLHEP.git

# Build CLHEP
RUN cd CLHEP && mkdir build && cd build                                        \
    && cmake -GNinja .. && ninja

# Test our CLHEP build
RUN cd CLHEP/build && ctest -j8

# Install CLHEP
RUN cd CLHEP/build && ninja install

# Get rid of the CLHEP build directory
RUN rm -rf CLHEP


# === INSTALL HEPPDT v2 ===

# Download and extract HepPDT v2
RUN curl                                                                       \
      http://lcgapp.cern.ch/project/simu/HepPDT/download/HepPDT-2.06.01.tar.gz \
      | tar -xz

# Build and install HepPDT
RUN cd HepPDT-2.06.01 && mkdir build && cd build                               \
    && ../configure && make -j8 && make install

# Get rid of the HepPDT build directory
RUN rm -rf HepPDT-2.06.01


# === INSTALL HEPMC v3 ===

# Download HepMC v3
RUN git clone --depth=1 https://gitlab.cern.ch/hepmc/HepMC3.git

# Build and install HepMC
RUN cd HepMC3 && mkdir build && cd build                                        \
    && cmake .. && make -j8 && make install

# Get rid of the HepMC build directory
RUN rm -rf HepMC3


# === INSTALL HEPMC v2 ===

# NOTE: Why are we overwriting our HepMC3 install with a HepMC2 one, you may
#       wonder? The answer has to do with RELAX being hopelessly broken, and
#       expecting the CMake files of HepMC3 together with the headers of HepMC2

# Dowload HepMC v2
RUN git clone --depth=1 https://gitlab.cern.ch/hepmc/HepMC.git

# Build HepMC
RUN cd HepMC && mkdir build && cd build                                        \
    && cmake -Dmomentum=GEV -Dlength=MM .. && make -j8

# Test our build of HepMC
RUN cd HepMC/build && make test -j8

# Install HepMC
RUN cd HepMC/build && make install

# Get rid of the HepMC build directory
RUN rm -rf HepMC


# === INSTALL RELAX ===

# Downlad and extract RELAX (yes, this file is not actually gzipped)
RUN curl http://lcgpackages.web.cern.ch/lcgpackages/tarFiles/sources/RELAX-root6.tar.gz \
      | tar -x

# Build and install RELAX (wow, such legacy, much hacks!)
RUN cd RELAX && mkdir build && cd build                                        \
    && ln -s `which genreflex` /genreflex                                      \
    && export CXXFLAGS="-I/usr/local/include/root/"                            \
    && cmake .. && make -j8 && make install                                    \
    && rm /genreflex && unset CXXFLAGS

# Get rid of the RELAX build directory
RUN rm -rf RELAX


# === ATTEMPT A GAUDI TEST BUILD ===

# Clone the Gaudi repository
RUN git clone --origin upstream https://gitlab.cern.ch/gaudi/Gaudi/

# Configure Gaudi
RUN cd Gaudi && mkdir build && cd build                                        \
    && cmake -DGAUDI_DIAGNOSTICS_COLOR=ON -GNinja ..

# Configure the run-time linker
#
# NOTE: I am not sure why this is needed for this build specifically, but the
#       Gaudi build will fail to find CLHEP if we don't do it.
#
RUN ldconfig

# Build Gaudi
RUN cd Gaudi/build && ninja

# Test the Gaudi build
#
# NOTE: Some Gaudi tests do ptrace system calls, which are not allowed in
#       unprivileged docker containers because they leak too much information
#       about the host. You can allow the container to run these tests
#       by passing the "--security-opt=seccomp:unconfined" flag to docker run,
#       but for some strange reason this flag cannot be passed to docker build.
#       Therefore, we disable these tests during the docker image build.
#
RUN cd Gaudi/build                                                             \
    && ctest -j8 -E "(google_auditors\.heapchecker|event_timeout_abort)"

# Remove build byproducts to keep image light
RUN cd Gaudi/build && ninja clean


# === FINAL CLEAN UP ===

# Clean up the APT cache
RUN apt-get clean