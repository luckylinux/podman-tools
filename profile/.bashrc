# Load Default Profile
if [[ -f /etc/skel/.bashrc ]]
then
    source /etc/skel/.bashrc
fi

# Load other alternate Profiles
if [[ -f /usr/share/dot.bashrc ]]
then
    source /usr/share/dot.bashrc
fi

# Load basic Profile (typically found on Alpine Linux)
if [[ -f /etc/bash/bashrc ]]
then
    source /etc/bash/bashrc
fi

# Load Profile Includes if any exist
if [[ -d ~/.profile.d ]]
then
    for include in $HOME/.profile.d/*include
    do
        source "${include}"
    done
fi
