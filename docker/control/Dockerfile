FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    openssh-client \
    sshpass \
    && pip3 install ansible

WORKDIR /ansible
CMD ["tail", "-f", "/dev/null"]
