FROM registry.fedoraproject.org/fedora-toolbox:33

ARG uid=1000
ARG gid=1000

RUN groupadd -g ${gid} testuser
RUN useradd -u ${uid} -g ${gid} -G wheel testuser
RUN mkdir -m 0755 /logs && chown ${uid}:${gid} /logs

ENV HOME=/home/testuser

RUN sed -i \
    -e '/^# *%wheel[ \t]*ALL=(ALL)[ \t]*NOPASSWD: *ALL *$/s@^# *@@' \
    -e '/^ *%wheel[ \t]*ALL=(ALL)[ \t]*ALL *$/s@^@# @' \
    /etc/sudoers

USER ${uid}:${gid}

WORKDIR /home/testuser
CMD /bin/bash
