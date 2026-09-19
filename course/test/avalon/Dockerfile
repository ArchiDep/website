# The machines of the Avalon play-through test: the SSH exercise server, and a
# student's computer, both from this image. See ../avalon.test.sh.
FROM ubuntu:24.04

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openssh-client openssh-server sshpass \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /run/sshd

# The student's account on the server, which logs in with a password until it
# has a key, as on the exercise server; and the student on their own computer.
RUN useradd --create-home --shell /bin/bash jde \
  && echo 'jde:secret' | chpasswd \
  && useradd --create-home --shell /bin/bash student
