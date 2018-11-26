#!/bin/bash -e
#/
#/
#/ Install Azul Zulu JDK on Amazon Linux
#/ Please note, it also removes all other JDK installed
#/
#/ Options:
#/   -v - more verbose output
#/   -r, --revision REV - the Azul Zulu JDK RPM revision to install (default is 8)
# Example:
#   ./install-zulu-jdk.sh
#   ./install-zulu-jdk.sh -r 9

set -euo pipefail

#
# Display usage of the script, which is a specially marked comment
#
usage() {
  grep '^#/' <"$0" | cut -c 4-
}

#
# Check if the debug mode has been enabled, ie ${DEBUG} is set to true
#
is_debug() {
  "${DEBUG:-false}"
}

#
# Display some debug message if debug mode has been enabled
#
# Example: debug Some debug message here
debug() {
  if is_debug
  then
    echo "$@" >&2
  fi
}

#
# Exits the process with a status indicating error
#
error() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [ERROR] $@" >> /dev/stderr
    exit 1
}

OPTS=`getopt -o vr: --long revision: -n "${0}" -- "$@"`

if [ $? != 0 ] ; then error "Failed parsing options." ; exit 1 ; fi

eval set -- "$OPTS"

ZULU_REVISION=8

while true; do
  case "$1" in
    -v) DEBUG=true; shift ;;
    -r | --revision) ZULU_REVISION="$2"; shift; shift ;;
    -h | --help )    usage; exit 75 ;;
    -- ) shift; break ;;
    * ) echo "Don't know what to do with $1"; usage; exit 75 ;;
  esac
done

# At this point there shouldn't be any arguments

if [ $# -ne 0 ]
then
  usage
  error "Obsolete command line argument!"
fi

debug "Importing Azul public key"
sudo rpm --import http://repos.azulsystems.com/RPM-GPG-KEY-azulsystems

debug "Adding Azul yum repository"
test -f /etc/yum.repos.d/zulu.repo || sudo curl -o /etc/yum.repos.d/zulu.repo http://repos.azulsystems.com/rhel/zulu.repo

debug "Installing Azul Java 8"
test $(rpm -qa zulu-"${ZULU_REVISION}"\* | wc -l) -gt 0 || sudo yum install -y zulu-"${ZULU_REVISION}"

debug "Removing old OpenJDK installations (7 & 8)"
rpm -qa java-1.8.0-openjdk\*| while read p; do sudo yum remove -y "${p}"; done
rpm -qa java-1.7.0-openjdk\*| while read p; do sudo yum remove -y "${p}"; done

debug "Checking if the Azul Zulu JDK is the default Java installation"
if [ $(java -version 2>&1 | grep Zulu | wc -l) -gt 0 ]
then
  echo "Azul Zulu JDK installation complete"
else
  error "Something went wrong, Azul Zulu JDK is not a default Java installation on this server.\nPlease investigate."
fi