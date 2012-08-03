#!/bin/bash

## Install script for riak


default_version="1.1.4"
default_relnum="1"
default_tmpdir="/tmp"
default_install_path="/opt"

function print_help(){
    cat <<EOF
Usage: $0 [-v <ver>] [-r <rel>] [-t <tmp>] [-i <inst>] [-h]
    Where:
        -v <ver> - version to install
        -r <rel> - release to install
        -t <tmp> - temp dir to use ( /tmp/ is default )
        -i <inst> - install dir ( for OSX, /opt is default )
        -h - this help screen

############################################################

Typical usage:

    curl http://url/install | sh

    curl http://url/install | <option>=<value> sh
    
    Where <option>=<value> can be:
        version=x.x.x.x
        relnum=x
        tmpdir="/other/dir"
        install_path="/other/path"

EOF
}

function run_me(){
    if [ $(whoami) = "root" ]; then
        echo "$@"
        if ! $@; then
            echo "Encountered error, exiting"
            exit 1
        fi
    else
        echo "sudo $@"
        if ! sudo $@; then
            echo "Encountered error, exiting"
            exit 1
        fi
    fi
}

function download(){
    echo "Downloading $1"
    echo "Saving to $2"
    if [ -f $2 ]; then
        echo "File already exists at $2, skipping download"
    elif which curl >/dev/null 2>&1; then
        curl $1 -o $2;
    elif which wget >/dev/null 2>&1; then
        wget -O $2 $1;
    else
        echo "Unable to find curl or wget, exiting"
        exit 1
    fi

    if [ ! -f "${tmpdir}/${file}" ]; then
        "There was an error downloading ${file} to ${tmpdir}"
        exit 1
    fi
}


while getopts v:t:r:i: opt; do
    case "$opt" in
        v) version="$OPTARG";;
        r) relnum="$OPTARG";;
        t) tmpdir="$OPTARG";;
        i) install_path="$OPTARG";;
        h) print_help && exit 0;;
       \?) print_help && exit 1;;
    esac
done

[ -z $version ] && version=$default_version
[ -z $relnum ] && relnum=$default_relnum
[ -z $tmpdir ] && tmpdir=$default_tmpdir
[ -z $install_path ] && install_path=$default_install_path

UNAME=$(uname);
case $(uname -m|tr '[:upper:]' '[:lower:]') in
    x86_64)
        ARCH="x86_64"
        ;;
    *)
        ARCH="i386"
esac

if [ "${UNAME}" == "Darwin" ]; then
    OS="osx"
elif [ "${UNAME}" == "SunOS" ]; then
    OS="solaris"
elif [ "${UNAME}" == "Linux" ]; then
    if [ -f "/etc/lsb-release" ]; then
        OS=$(grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[:upper:]' '[:lower:]');
        ARCH=$(echo $ARCH|sed 's/x86_/amd/')
    elif [ -f "/etc/debian_version" ]; then
        OS="debian";
        ARCH=$(echo $ARCH|sed 's/x86_/amd/')
    elif [ -f "/etc/redhat-release" ]; then
        OS=$(sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[:upper:]' '[:lower:]')
        if [ "${OS}" = "centos" ]; then
            OS="redhat"
        fi
        REL=$(sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release | cut -d "." -f 1)
    elif [ -f "/etc/system-release" ]; then
        if grep -i "amazon linux ami" /etc/system-release 1>/dev/null 2>&1; then
            OS="redhat"
            REL="6"
        else 
            OS=$(sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[:upper:]' '[:lower:]')
        fi
    fi
fi

if [ "x$OS" = "x" ]; then
    echo "Unable to find suitable package for ${UNAME}"
    exit 1
fi

majver=$(echo $version | cut -d "." -f 1,2)

url="http://s3.amazonaws.com/downloads.basho.com/riak/${majver}/${version}"
case "${OS}" in
    osx)
        method="tar"
        file="riak-${version}-osx-${ARCH}.tar.gz"
        ;;
    solaris)
        method="pkg"
        ARCH="i386" # no 64bit packages for Solaris
        file="BASHOriak-${version}-${relnum}-Solaris10-${ARCH}.pkg"
        ;;
    ubuntu)
        method="deb"
        file="riak_${version}-${relnum}_${ARCH}.deb"
        if ! dpkg -s libssl0.9.8 > /dev/null 2>&1; then
            echo "Installing dependency: libssl0.9.8"
            run_me apt-get install -y libssl0.9.8
        fi
        ;;
    debian)
        method="deb"
        file="riak_${version}-${relnum}_${ARCH}.deb"
        ;;
    fedora)
        method="yum"
        file="riak-${version}-${relnum}-fc15.${ARCH}.rpm"
        ;;
    redhat)
        method="yum"
        file="riak-${version}-${relnum}.el${REL}.${ARCH}.rpm"
        ;;
    *)
        echo "Unhandled OS type"
        exit 1
esac

case "${method}" in
    yum)
        if which yum > /dev/null 2>&1; then
            run_me yum -y install "${url}/${file}"
        else
            run_me rpm -Uvh "${url}/${file}";
        fi
        ;;
    deb)
        download "${url}/${file}" "${tmpdir}/${file}";
        if run_me dpkg -i "${tmpdir}/${file}"; then
            run_me rm -f "${tmpdir}/${file}"
        else
            echo "Error installing ${tmpdir}/${file}"
            echo "Leaving ${tmpdir}/${file} for debugging"
            exit 1
        fi
        ;;
    tar)
        download "${url}/${file}" "${tmpdir}/${file}";
        run_me tar -xzf "${tmpdir}/${file}" -C "${install_path}"
        basedir="${install_path}/riak-${version}"
        for binfile in $(find "${basedir}/bin" -type f -perm -u+x); do
            run_me perl -pi -e "s!^(RUNNER_BASE_DIR=).*!\1${basedir}!" $binfile
            if [ ! -f "/usr/local/bin/$(basename $binfile)" ]; then
                run_me ln -s ${binfile} /usr/local/bin/
            fi
        done
        run_me rm -f "${tmpdir}/${file}"
        ulimit -n 2048
        launchctl limit maxfiles 2048 2048
        ;;
    pkg)
        echo "Solaris Install currently untested, downloading files and echoing commands..."
        download "${url}/${file}.gz" "${tmpdir}/${file}.gz";
        gunzip "${tmpdir}/${file}.gz"
        echo "Would execute: pkgadd -d \"${tmpdir}/${file}\""
        ;;
    *)
        echo "Method: ${method}"
        echo "File: ${file}"
        echo "Not handled yet, try back later"
esac
