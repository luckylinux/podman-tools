#!/bin/bash

# Check to make sure that we are running inside LXC Container
grep -qa container=lxc /proc/1/environ
status=$?

if [ ${status} -eq 0 ]
then
    # Debug
    # echo "Running in LXC"

    # Check Permissions for newuidmap
    permissions_newuidmap=$(stat --format=%a /usr/sbin/newuidmap)

    # Check Permissions for newgidmap
    permissions_newgidmap=$(stat --format=%a /usr/sbin/newgidmap)

    if [[ $(command -v dpkg) ]]
    then
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
    elif [[ $(command -v dnf) ]]
    then
        # Get Capabilities
        capabilities_newuidmap=$(getcap -v /usr/bin/newuidmap)
        echo "${capabilities_newuidmap}" | grep -qa cap_setuid=ep > /dev/null
        status_newuidmap=$?

        capabilities_newgidmap=$(getcap -v /usr/bin/newgidmap)
        echo "${capabilities_newgidmap}" | grep -qa cap_setgid=ep > /dev/null
        status_newgidmap=$?

        if [ ${status_newuidmap} -ne 0 ]
        then
            # Echo
            echo "Set cap_setuid=ep for /usr/sbin/newuidmap"

            # Set Capability
            setcap cap_setuid=ep /usr/bin/newuidmap
        fi

        if [ ${status_newgidmap} -ne 0 ]
        then
            # Echo
            echo "Set cap_setgid=ep for /usr/sbin/newgidmap"

            # Set Capability
            setcap cap_setgid=ep /usr/bin/newgidmap
        fi
    fi
else
    # Do nothing
    x=1

    # Debug
    # echo "NOT running in LXC"
fi

