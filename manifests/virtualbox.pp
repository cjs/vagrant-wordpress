$wordpress_version = '3.4.1'

Exec {
  path => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
}
#Setup repositories
class { 'apt':
  always_apt_update => true,
}

#Install default applications
case $::operatingsystem {
  default: { $default_packages = ['tree','zip','unzip','subversion','wget','ant','ant-contrib','python-setuptools'] }
}

package { $default_packages:
  ensure  => latest,
}

#Setup services
class { 'ufw': }

class { 'ssh::client': }
ufw::allow { 'allow-ssh-from-all':
  port => 22,
}

class { 'ntp': }
ufw::allow { 'allow-ntp-from-all':
  port => 123,
}

case $::operatingsystem {
  default: { $project_packages = ['php5-cli','php-pear','php5-mysql','php5-gd'] }
}

package { $project_packages:
  ensure   => latest,
}

class { 'apache': }
class { 'apache::php': }

class { 'mysql': }
class { 'mysql::server':
  config_hash => { 'root_password' => 'vagrant' }
}

file { '/home/vagrant/wordpress-data':
  ensure => directory,
  owner  => 'www-data',
  group  => 'www-data',
  mode   => '777',
}

exec { 'download-wordpress':
  command => "wget http://wordpress.org/latest.zip -O /home/vagrant/wordpress-$wordpress_version.zip",
  creates => "/home/vagrant/wordpress-$wordpress_version.zip",
  require => Package[$default_packages],
}

exec { 'unzip-wordpress-zip':
  command => "unzip /home/vagrant/wordpress-$wordpress_version.zip  -d /home/vagrant",
  creates => "/home/vagrant/wordpress",
  require => Exec['download-wordpress'],
}

file { "/home/vagrant/wordpress":
  ensure  => directory,
  owner   => 'www-data',
  group   => 'www-data',
  recurse => true,
  mode    => '777',
  require => Exec['unzip-wordpress-zip'],
}

file { '/home/vagrant/wordpress-www':
  ensure  => link,
  target  => "/home/vagrant/wordpress",
  require => File["/home/vagrant/wordpress"],
}

apache::vhost { 'wordpress.test':
  priority           => '20',
  port               => '80',
  docroot            => '/home/vagrant/wordpress-www',
  configure_firewall => false,
  require            => [Exec['unzip-wordpress-zip'],File['/home/vagrant/wordpress-data']],
}
ufw::allow { 'allow-http-from-all':
  port => 80,
}

mysql::db { 'wordpress':
  user     => 'wordpress',
  password => 'wordpress',
  host     => 'localhost',
  grant    => ['all'],
  require  => Class['mysql::server'],
}