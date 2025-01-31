# podman
Podman Tools and Configurations

## Useful Documents for Related Stuff

## Transfer Images between Host Automatically
This Article explains the Process and the different Options in Detail: https://www.redhat.com/sysadmin/podman-transfer-container-images-without-registry

Nevertheless this requires additional Configuration as well as the use of SSH Key Authentication.

Command(s) to run on the Source Host in order to perform Configuration:
```
# On the Source Host
podman system connection add ...
```

Command(s) to run on the Source Host in order to perform Transfer:
```
# Define Parameters
container="traefik"
destination="192.168.8.15"
user="podman"

# On the Source Host to Transfer Image to the Destination Host
podman image scp ${container} ${user}@${destination}::${container}
```


## Save Images and Push between Hosts Manually
Manual Method by saving/exporting a .tar archive on the Source Host, transfer it using scp, then reimport it on the Destination Host.

Command(s) to run on the Source Host in order to Save and Transfer the Image:
```
# Define Parameters
container="traefik"
destination="192.168.8.15"
user="podman"

# Save/Export Image to .tar Archive:
podman image save -m -o ~/containers/local/images/${container}.tar ${container}

# Transfer .tar Image to the Target Host
scp ~/containers/local/images/${container}.tar ${user}@${destination}:/home/${user}/containers/local/images/{$container}.tar
```

Command(s) to run on the Destination Host:
```
container="traefik"

# Import .tar Image into library
podman image load --input ~/containers/local/images/${container}.tar
```
