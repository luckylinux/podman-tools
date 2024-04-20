#!/bin/bash

read -p "Enter Username: " username

read -s -p "Enter Password: " password

echo -e "\n"

htpasswd -bnBC 10 ${username} ${password}

echo -e "\n"

htpasswd -bnBC 10 "" ${password} | tr -d ':\n'

echo -e "\n"
