##########
# Created for Shawn H. - Replication of EC2 setup script
##########

## Ensure iptables is not running and off at boot.

service { "iptables":
    ensure  => stopped,
    enable  => false,
}

## Set SELINUX as permissive

file { "/etc/selinux/config":
    ensure  => present,
    content => "# This file is managed via Puppet, plan accordingly
			 # This file controls the state of SELinux on the system.
			 # SELINUX= can take one of these three values:
			 #       enforcing - SELinux security policy is enforced.
			 #       permissive - SELinux prints warnings instead of enforcing.
			 #       disabled - SELinux is fully disabled.
			 SELINUX=disabled
			 # SELINUXTYPE= type of policy in use. Possible values are:
			 #       targeted - Only targeted network daemons are protected.
			 #       strict - Full SELinux protection.
			 SELINUXTYPE=permissive",
}

##

## Here we set the hostname

file { "/etc/sysconfig/network":
    ensure  => present,
    content => "NETWORKING="yes" HOSTNAME="mgmtnode.adaptive.com"",
}

## Here we manage users - Rinse and repeat the code block with the max number of students anticipated

user { 'alice':
  ensure           => 'present',
  comment          => 'Alice,,,',
  gid              => '1003',
  groups           => ['adm'],
  home             => '/home/alice',
  provider         => 'useradd',
  password         => '$1$Rhc.DNKE$meLsKnow787qqCaXUkBPc/',
  password_max_age => '99999',
  password_min_age => '0',
  shell            => '/bin/bash',
  uid              => '1001',
}

## Install all perl and php packages as well as https

package { "perl*":
    ensure => installed,
}

package { "php*":
    ensure => installed,
}

package { "httpd":
    ensure => installed,
}

