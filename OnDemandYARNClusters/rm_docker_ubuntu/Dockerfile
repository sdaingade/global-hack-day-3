FROM ubuntu:14.04
MAINTAINER ss <sarjeetsingh@maprtech.com>
RUN echo "deb http://apt.qa.lab/myriad mapr optional" >> /etc/apt/sources.list
RUN echo "deb http://apt.qa.lab/opensource binary/" >> /etc/apt/sources.list
RUN sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
RUN echo "deb http://repos.mesosphere.io/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
RUN apt-get -y install wget
RUN wget http://package.mapr.com/releases/pub/maprgpg.key
RUN apt-key add maprgpg.key
RUN sudo apt-get -y update
<<<<<<< HEAD
RUN apt-get install openjdk-7-jdk -y
RUN apt-get install mapr-cldb mapr-fileserver mapr-zookeeper mapr-myriad-scheduler mapr-myriad-executor -y
=======
RUN apt-get -y install openjdk-7-jdk
RUN apt-get -y --allow-unauthenticated install mapr-cldb mapr-fileserver mapr-zookeeper mapr-myriad-scheduler mapr-myriad-executor

COPY init-script /usr/bin/init-script
ENTRYPOINT /usr/bin/init-script
>>>>>>> 88bb2e5... Added init-script for setting up mapr user/group and run configure.sh inside container, Modified Dockerfiles to add the init-script
