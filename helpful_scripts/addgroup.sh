#!/bin/bash


# Create a group.
# Takes a group name and gid and creates a new group in NetInfo groups


usage ()
{
  echo "Create a new group"
  echo "Usage: ${0##*/} groupname gid"
  if [ "$*" != "" ]; then echo "  Error: $*"; fi
  exit 1
}




# The script must be run as root
#
if [ "$USER" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi




# Check parameters
#
if [ $# -ne 2 ]; then
  usage
fi


group=$1; gid=$2


# search NetInfo for the given group - it should not exist
str="$(nireport . /groups name | grep -w $group)"
if [ ! -z "$str" ]; then
  usage "Group $group already exists"
fi


# search NetInfo for the given gid - it should not exist
str="$(nireport . /groups gid | grep -w $gid)"
if [ ! -z "$str" ]; then
  usage "Group ID $gid already exists"
fi




# Add the new group to NetInfo
#
# add group and essential properties
dscl . create /groups/$group
dscl . create /groups/$group name $group
dscl . create /groups/$group passwd "*"
dscl . create /groups/$group gid $gid
#dscl . create /groups/$group users "" breaks add-user2group if added as a blank value


echo "New group $group created"
echo "Now add users to it with add-user2group"


exit 0

