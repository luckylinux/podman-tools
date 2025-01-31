# Load Default Profile
source /etc/skel/.bashrc

# Load Profile Includes if any exist
if [[ -d ~/.profile.d ]]
then
    for include in $HOME/.profile.d/*include
    do
        source "${include}"
    done
fi
