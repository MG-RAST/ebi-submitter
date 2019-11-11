FROM perl:5.24
LABEL maintainer="Andreas Wilke <wilke@mcs.anl.gov"
RUN cpanm XML::LibXML \
  JSON \
  LWP \
  LWP::Protocol::https \
  HTTP::Request::StreamingUpload \
  XML::Simple 
COPY . /usr/src/ebi-submitter
WORKDIR /usr/src/ebi-submitter/
RUN chmod a+x scripts/*
ENV PATH $PATH:/usr/src/ebi-submitter/scripts
ENV PERL5LIB $PERL5LIB:/usr/src/ebi-submitter/scripts/lib
CMD [ "perl", "./scripts/submitMgrastProject.pl" ]
