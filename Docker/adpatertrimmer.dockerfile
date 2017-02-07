FROM ubuntu:latest
MAINTAINER Andreas Wilke <wilke@mcs.anl.gov>

# example: docker build -t autoskewer:latest .



RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y curl \
  g++ \
  git \
  make \
  python \
  unzip \
  wget

# bowtie
RUN wget --content-disposition http://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.2.5/bowtie2-2.2.5-linux-x86_64.zip/download && unzip bowtie2-2.2.5-linux-x86_64.zip && cp /bowtie2-2.2.5/bowtie2* /usr/local/bin


# skewer
# RUN git clone http://github.com/wltrimbl/skewer && cd skewer && make && make install
RUN git clone https://github.com/relipmoc/skewer && cd skewer && make && make install

#autoskewer
RUN git clone http://github.com/MG-RAST/autoskewer && cd autoskewer && make

ENV PATH /autoskewer/:$PATH

CMD ["bash"]

