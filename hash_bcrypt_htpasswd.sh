#!/bin/bash

read -p "Enter Username: " username

read -s -p "Enter Password: " password

htpasswd -bnBC 10 $username $password

htpasswd -bnBC 10 "" $password | tr -d ':\n'

