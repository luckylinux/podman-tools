#!/bin/bash

# Check to make sure that we are running inside LXC Container
status=$(grep -qa container=lxc /proc/1/environ)

if [ ${status} -eq 0 ]
then
    # Debug
    # echo "Running in LXC"

    # Check Permissions for newuidmap
    permissions_newuidmap=$(stat --format=%a /usr/sbin/newuidmap)

    # Check Permissions for newgidmap
    permissions_newgidmap=$(stat --format=%a /usr/sbin/newgidmap)

    # Check if Permissions are NOT correct
    if [[ "${permissions_newuidmap}" != "4755" ]]
    then
        # Echo
        echo "Permissions for /usr/sbin/newuidmap are NOT correct (${permissions_newuidmap})"
        echo "Setting Permissions to 4755 for /usr/sbin/newuidmap"

        # Change Permissions
        chmod 4755 /usr/sbin/newuidmap
    fi

    if [[ "${permissions_newgidmap}" != "4755" ]]
    then
        # Echo
        echo "Permissions for /usr/sbin/newgidmap are NOT correct (${permissions_newgidmap})"
        echo "Setting Permissions to 4755 for /usr/sbin/newgidmap"

        # Change Permissions
        chmod 4755 /usr/sbin/newgidmap
    fi
else
    # Do nothing
    x=1

    # Debug
    # echo "NOT running in LXC"
fi

