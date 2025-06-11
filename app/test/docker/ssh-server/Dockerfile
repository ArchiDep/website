FROM ubuntu:noble

LABEL maintainer="contact@archidep.ch"

RUN apt update -y && \
    apt install -y \
      bash \
      openssh-server \
      openssh-sftp-server \
      sudo \
      tzdata \
    && \
    apt-get clean && \
    rm -rf /tmp/* && \
    mkdir -p /etc/openssh /run/sshd /var/run/openssh && \
    chmod 700 /etc/openssh /var/run/openssh && \
    mv /etc/ssh/sshd_config /etc/openssh/sshd_config && \
    chmod 644 /etc/openssh/sshd_config

ARG JDE_UID=1000

RUN useradd --comment "John Doe" --create-home --shell /bin/bash jde --uid "$JDE_UID" && \
    mkdir -p /home/jde/.ssh && \
    chmod 700 /home/jde/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIxsZfyuRVJsWGYbLaZLTCDahyT9QhnT1ixzfLPILK4A archidep-test" > /home/jde/.ssh/authorized_keys && \
    chmod 600 /home/jde/.ssh/authorized_keys && \
    chown -R jde:jde /home/jde/.ssh && \
    echo "jde ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/jde && \
    chmod 440 /etc/sudoers.d/jde

CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/etc/openssh/sshd_config", "-p", "22"]
