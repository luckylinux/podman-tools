# Load .bashrc if it exists
if [ -f ~/.bashrc ]
then
   . ~/.bashrc
fi

# Load Profile Includes if any exist
if [[ -d ~/.profile.d ]]
then
    for include in $HOME/.profile.d/*include
    do
        source "${include}"
    done
fi

