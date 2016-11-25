%define _topdir /root/rpmbuild

Name:       percona-server
Version:    5.6.33
Release:    1%{?dist}
Summary:    percona-server-5.6.33 RPM

Group:      applications/database
License:    GPL    
URL:        https://www.percona.com
Source0:    percona-server-5.6.33.tar.gz
BuildRoot:      %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires:  cmake

AutoReqProv: no
%description
percona-server 5.6.33

%define MYSQL_USER mysql
%define MYSQL_GROUP mysql

%prep
%setup -n percona-server-%{version}

%build
cmake \
-DCMAKE_INSTALL_PREFIX=/opt/letv/mysql \
-DMYSQL_DATADIR=/srv/mcluster/mysql \
-DSYSCONFDIR=/opt/letv/mysql/etc \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DMYSQL_UNIX_ADDR=/var/lib/mysql/mysqld.sock \
-DMYSQL_TCP_PORT=3306 \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci
make -j `cat /proc/cpuinfo | grep processor| wc -l`

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%pre
groupadd mysql
useradd mysql -s /sbin/nologin -M -g mysql
mkdir -p /opt/letv/mysql
mkdir -p /opt/letv/mysql/etc
mkdir -p /var/lib/mysql
mkdir -p /var/log/mysql
chown -R mysql:mysql /opt/letv/mysql
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/log/mysql

%post
cp /opt/letv/mysql/support-files/mysql.server /etc/init.d/mysql
chmod 755 /etc/init.d/mysql
echo 'export PATH=.:$PATH:/opt/letv/mysql/bin' >> /etc/profile
export PATH=.:$PATH:/opt/letv/mysql/bin
source /etc/profile
#/opt/letv/mysql/scripts/mysql_install_db --basedir=/opt/letv/mysql --user=mysql --datadir=/srv/mcluster/mysql
#service mysql start

%preun
service mysql stop
userdel mysql
rm -rf /etc/init.d/mysql

%clean
rm -rf %{buildroot}


%files
%defattr(-, %{MYSQL_USER}, %{MYSQL_GROUP})
%attr(755, %{MYSQL_USER}, %{MYSQL_GROUP}) /opt/letv/mysql/*


%changelog
