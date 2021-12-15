#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler & Goran Bogojevic


source ./0a_aporeto_config

sudo curl -o /usr/local/bin/apoctl \
  	 --url https://download.aporeto.com/prismacloud/$PRISMA_APP_STACK/apoctl/linux/apoctl \
     && sudo chmod 755 /usr/local/bin/apoctl

