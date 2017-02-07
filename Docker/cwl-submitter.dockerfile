FROM ubuntu:latest
RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y cpanminus \
  curl \
  g++ \
  git \
  libexpat1-dev \
  libjson-perl \
  libjson-xs-perl \
  libwww-perl \
  libxml2-dev \
  libxml-perl \
  make \
  perl \
  python \
  unzip \
  wget \
  zlib1g-dev
  
# RUN cpanm JSON \
#   LWP \
#   LWP::Protocol::https \
#   HTTP::Request::StreamingUpload \
#   XML::LibXML XML::Simple
# RUN cpanm JSON \
#     XML::LibXML \
#     XML::Simple

WORKDIR /Downloads
RUN curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" ; \
  python get-pip.py ; \
  pip install cwlref-runner
# bowtie
RUN wget --content-disposition http://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.2.5/bowtie2-2.2.5-linux-x86_64.zip/download && \
  unzip bowtie2-2.2.5-linux-x86_64.zip && \
  cp bowtie2-2.2.5/bowtie2* /usr/local/bin
# skewer
RUN git clone https://github.com/relipmoc/skewer && \
  cd skewer && \
  make && \
  make install

# node.js version 7
RUN curl -sL https://deb.nodesource.com/setup_7.x | bash - ;\
  apt-get install -y nodejs 

# Perl script
WORKDIR /usr/src

#autoskewer
RUN git clone http://github.com/MG-RAST/autoskewer && cd autoskewer && make
ENV PATH /usr/src/autoskewer/:$PATH

# submission script
COPY . ebi-submitter
RUN chmod a+x ebi-submitter/scripts/*
ENV PATH /usr/src/ebi-submitter/scripts:$PATH

CMD ["cwltool"]



