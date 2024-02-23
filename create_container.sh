#!/bin/bash

read -p "Enter Container Name: " cname

podman run --name ${cname} -p 80:80 -d ${cname}:latest
