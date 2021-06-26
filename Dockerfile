FROM ubuntu:20.04

ADD https://geomarker.s3.us-east-2.amazonaws.com/geocoder_2019.db /opt/geocoder.db
# COPY geocoder_2019.db /opt/geocoder.db

RUN apt-get update && apt-get install -y --no-install-recommends\
    libssl-dev \
    libssh2-1-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    make \
    nano \
    sqlite3 \
    libsqlite3-dev \
    flex \
    ruby-full \
    bison \
    gnupg \
    software-properties-common \
    && apt-get clean

RUN apt-get install -y libgdal-dev g++ --no-install-recommends && \
    apt-get clean -y



    # Update C env vars so compiler can find gdal
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

RUN gem install sqlite3 json Text

RUN mkdir /root/geocoder
WORKDIR /root/geocoder

COPY Makefile.ruby .
COPY app.R .
COPY tract_mapping.R .

COPY /src ./src
COPY /lib ./lib
COPY /gemspec ./gemspec
COPY /Shapefiles ./Shapefiles


RUN cd /root/geocoder \
    && make -f Makefile.ruby install \
    && gem install Geocoder-US-2.0.4.gem

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
    && add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/' \
    && apt update \
    && apt install -y r-base r-base-dev

# install required version of renv
RUN R --quiet -e "install.packages('remotes', repos = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest')"
# make sure version matches what is used in the project: packageVersion('renv')
ENV RENV_VERSION 0.13.2
RUN R --quiet -e "remotes::install_github('rstudio/renv@${RENV_VERSION}')"

COPY renv.lock .
RUN R --quiet -e "renv::restore(repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'), \
                                rebuild = c('rgeos', 'rgdal'))"

#deal with shared object aliases for rgdal and rgeos
#RUN R --quiet -e "install.packages('devtools', repos = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest')"
#RUN R --quiet -e "devtools::install_version('rgdal', version = '1.5.23')"
#RUN R --quiet -e "devtools::install_version('rgeos', version = '0.5.5')"


COPY geocode.R .
COPY geocode.rb .

ENTRYPOINT ["./geocode.R"]
