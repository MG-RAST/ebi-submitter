FROM perl:5.24
RUN cpanm XML::LibXML JSON LWP LWP::Protocol::https HTTP::Request::StreamingUpload 
COPY . /usr/src/ebi-submitter
WORKDIR /usr/src/ebi-submitter/
RUN chmod a+x scripts/*
ENV PATH $PATH:/usr/src/ebi-submitter/scripts
CMD [ "perl", "./scripts/submitMgrastProject.pl" ]