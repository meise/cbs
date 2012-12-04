Check backup space
==================

* [Project][project]

   [project]: https://github.com/meise/cbs/


Description
-----------

Cbs is a Ruby script to check available disk space on remote systems via (s)ftp or ssh. The script can be used together with
[Nagios][nagios] or [Icinga][icinga] for backup spaces provided by
[Hetzner][hetzner] to every root or vServer.

[nagios]:http://www.nagios.org
[icinga]:https://www.icinga.org
[hetzner]:http://hetzner.de


Requirements
------------

* Ruby 1.8.7 or higher
* tftp


Usage
-----

You can use this script as any other nagios plugin. A example configuration looks as follows.

### Command line options

    Usage: check_backup_space.rb [options]

    Required options:
        -H, --host HOST                  Set backup host

        -u, --user USER                  Set user
        -p, --password PASS              Set user password

        -w, --warning SIZE               Set space left warning limit in GB
        -c, --critical SIZE              Set space left critical limit in GB
        -m, --maximum SIZE               Set maximum of your backup space capacity in GB

    Optional options:
        -f, --file /etc/nagios/password  Read password from file
            --protocol [PROTO]           Set set protocol to determine disk usage (default sftp)
            --[no]-verbose               Run verbosely

    Common options:
        -h, --help                       Show this message
        -v, --version                    Show check_backup_space.rb version

### Nagios Server

Define a new service for spezific host.

    define service{
        use                             remote-service
        host_name                       server1
        service_description             available backup space
        check_command                   check_nrpe_external!check_backup_space
        contact_groups                  admins
    }

### Nrpe command definition

Define a new command in your nrpe configuration like this.

    command[check_backup_space]=/usr/lib/nagios/plugins/check_backup_space -u u123456 -f /etc/nagios/backup_space_password -H ipv6.u123456.your-backup.de -c 10 -w 20 -m 100

### Output

    BACKUP_SPACE OK - free space: 33GB of 100GB (w: 20GB c: 10GB)


License
-------

This script is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this script. If not, see <http://www.gnu.org/licenses/>.
