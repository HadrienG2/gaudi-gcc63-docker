Some of Gaudi's tests use ptrace system calls and will fail if the associated Docker confinment is not disabled with --security-opt=seccomp:unconfined .
