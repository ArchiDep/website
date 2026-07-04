FROM ubuntu:noble

LABEL maintainer="contact@archidep.ch"

ENV DEBIAN_FRONTEND=noninteractive

# systemd/systemd-sysv boot the container as a real init (PID 1) so the setup
# playbook's `ansible.builtin.systemd` tasks (daemon-reload, enabling units) run
# against a live systemd/dbus, exactly like the student VMs. dbus backs the
# systemctl D-Bus calls; openssh-sftp-server backs Ansible's file transfers;
# python3 is what Ansible executes on the managed node. sshd runs as a systemd
# unit (stock /etc/ssh config) rather than the container's foreground command.
RUN apt-get update -y && \
    apt-get install -y \
      bash \
      dbus \
      openssh-server \
      openssh-sftp-server \
      python3 \
      sudo \
      systemd \
      systemd-sysv \
      tzdata \
    && \
    systemctl enable ssh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

ARG JDE_UID=1000

# Ubuntu noble ships a default `ubuntu` user at UID 1000; remove it so `jde` can
# take that UID.
RUN userdel --remove ubuntu 2>/dev/null || true && \
    useradd --comment "John Doe" --create-home --shell /bin/bash jde --uid "$JDE_UID" && \
    mkdir -p /home/jde/.ssh && \
    chmod 700 /home/jde/.ssh && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE1Q2L2jlt2R71iHClMbx1uIIkKbBGMwGo5c1gFJVArH archidep" > /home/jde/.ssh/authorized_keys && \
    chmod 600 /home/jde/.ssh/authorized_keys && \
    chown -R jde:jde /home/jde/.ssh && \
    echo "jde ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/jde && \
    chmod 440 /etc/sudoers.d/jde

CMD ["/sbin/init"]
