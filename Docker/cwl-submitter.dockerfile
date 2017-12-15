FROM ubuntu:latest
RUN apt-get update && apt-get install -y \
  curl \
  g++ \
  git \
  libexpat1-dev \
  libjson-perl \
  libjson-xs-perl \
  libwww-perl \
  libxml-simple-perl \
  make \
  perl \
  python \
  python-pip \
  unzip \
  wget \
  zlib1g-dev

WORKDIR /Downloads

# cwl
RUN pip install cwlref-runner

# bowtie
RUN wget --content-disposition http://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.2.5/bowtie2-2.2.5-linux-x86_64.zip/download && \
  unzip bowtie2-2.2.5-linux-x86_64.zip && \
  cp bowtie2-2.2.5/bowtie2* /usr/local/bin

# node.js version 7
RUN curl -sL https://deb.nodesource.com/setup_7.x | bash - ; \
  apt-get install -y nodejs

# skewer
RUN git clone https://github.com/wltrimbl/skewer && \
  cd skewer && \
  make && \
  make install

WORKDIR /usr/src

# autoskewer
RUN git clone http://github.com/MG-RAST/autoskewer && \
  cd autoskewer && \
  make

ENV PATH /usr/src/autoskewer/:$PATH

# submission scripts
COPY . ebi-submitter
RUN chmod a+x ebi-submitter/scripts/* && \
  mkdir -p /usr/local/lib/site_perl && \
  cp -r /usr/src/ebi-submitter/scripts/lib/Submitter /usr/local/lib/site_perl/.
ENV PATH /usr/src/ebi-submitter/scripts:$PATH

CMD ["cwltool"]



