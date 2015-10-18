FROM centos:7
MAINTAINER ss <sarjeetsingh@maprtech.com>
RUN rpm -Uvh http://repos.mesosphere.io/el/6/noarch/RPMS/mesosphere-el-repo-6-2.noarch.rpm
RUN yum -y install yum-utils
RUN yum-config-manager --add-repo http://yum.qa.lab/myriad
RUN yum-config-manager --add-repo http://yum.qa.lab/opensource
RUN yum -y --nogpgcheck install java-1.7.0-openjdk.x86_64
RUN echo "exclude=mapr-compat-suse*" >> /etc/yum.conf
RUN yum clean all
RUN yum -y --nogpgcheck install mapr-cldb mapr-fileserver mapr-zookeeper mapr-myriad-scheduler mapr-myriad-executor

COPY init-script /usr/bin/init-script
ENTRYPOINT /usr/bin/init-script
