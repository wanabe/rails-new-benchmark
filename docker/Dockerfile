FROM ubuntu:16.04
RUN apt-get update && apt-get install -y build-essential bison libreadline6-dev curl git-core zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev autoconf libncurses5-dev ruby ruby-dev nodejs

ARG uid=0
ARG user=root
RUN if [ ${uid} != 0 ]; then \
    apt-get update && apt-get install -y sudo && \
    useradd -m ${user} -u ${uid} && \
    echo "${user}:${user}" | chpasswd && \
    usermod -G sudo ${user}; \
  fi

USER ${user}
CMD ["bash", "-li"]
