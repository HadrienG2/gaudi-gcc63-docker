# A GCC 6.3-based Gaudi build environment

The Gaudi continuous integration infrastructure runs a test build on GCC 6.2,
which happens not to be my system compiler. So off to Docker I went, and I
thought this would be a good opportunity to document all the oddities that one
needs to go through when building Gaudi on a sane Linux distribution.

To avoid rebuilding the whole world, I used Debian Stretch as a base, which is
built on GCC 6.3 rather than GCC 6.2. Hopefully that will be close enough for
the purpose of debugging CI build and test failures.

You can find a pre-built version of this docker image on the Docker Hub, it is
called hgrasland/gaudi-gcc63-tests .

If you are also using this image to debug a continuous integration issue, please
note that some of Gaudi's tests use ptrace system calls and will fail if the
associated Docker confinment is not disabled. You can achieve this with the
`--security-opt=seccomp:unconfined` CLI flag, though it is admittedly a bit of a
sledgehammer. If you know the fine-grained way, please send me a PR!