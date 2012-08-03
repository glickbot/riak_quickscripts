riak_quickscripts (alpha)
=========================

Scripts to help install & sync cluster configurations

install.sh
==========
Usage:

    https://github.com/glickbot/riak_quickscripts/blob/master/install.sh | sh

Better URL to come.

Works (preliminarily) on:
- MacOS
- Ubuntu/Debian
- Fedora
- Centos5/6
- Redhat5/6

Hasen't been tested on:
- Solaris
- SmartOS
- anything else

    Usage: install.sh [-v <ver>] [-r <rel>] [-t <tmp>] [-i <inst>] [-h]
    Where:
        -v <ver> - version to install
        -r <rel> - release to install
        -t <tmp> - temp dir to use ( /tmp/ is default )
        -i <inst> - install dir ( for OSX, /opt is default )
        -h - this help screen

    ############################################################

    Typical usage:

    curl https://github.com/glickbot/riak_quickscripts/blob/master/install.sh | sh

    curl https://github.com/glickbot/riak_quickscripts/blob/master/install.sh | <option>=<value> sh
    
    Where <option>=<value> can be:
        version=x.x.x.x
        relnum=x
        tmpdir="/other/dir"
        install_path="/other/path"
