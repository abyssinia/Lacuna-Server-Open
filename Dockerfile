FROM centos:centos6.6

ADD ./ /data/Lacuna-Server-Open

ENV LD_LIBRARY_PATH /data/Lacuna-Server-Open/apps/lib

RUN yum -y update; yum clean all
RUN yum -y install mysql-server mysql mysql-devel cpan tar wget; yum clean all

WORKDIR /data/Lacuna-Server-Open/bin/setup/server
RUN ./download.sh
RUN ./build.sh

WORKDIR /data/Lacuna-Server-Open/bin/setup
#RUN ./install-pm.sh

# start memcached
#RUN memcached -u daemon -d

# setup mysqld
#RUN chkconfig --levels 235 mysqld on
#RUN service mysqld start
#RUN mysql -uroot -e "CREATE DATABASE lacunadb"
#RUN mysql -uroot -e "GRANT ALL PRIVILEGES ON lacunadb.* TO 'lacuna'@'localhost' IDENTIFIED BY 'expanse'; FLUSH PRIVILEGES;"

#RUN perl init_lacuna.pl
#RUN perl generate_captcha.pl

#RUN echo "Lacuna-Server-Open Docker" > /var/www/public/index.html

EXPOSE 80
#EXPOSE 443

CMD /bin/bash
#CMD ["/data/Lacuna-Server-Open/bin/start_nginx.sh"]
