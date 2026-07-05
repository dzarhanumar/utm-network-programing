FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    iproute2 \
    net-tools \
    sudo \
    python3 \
    procps \
    util-linux \
    && mkdir /var/run/sshd

# Admin account used by Ansible to connect (simulates device login)
RUN useradd -m -s /bin/bash admin \
    && echo "admin:admin123" | chpasswd \
    && adduser admin sudo \
    && echo "admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
