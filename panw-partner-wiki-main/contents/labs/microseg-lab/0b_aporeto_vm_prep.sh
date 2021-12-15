#!/bin/bash

#for an ubuntu vm 


sudo systemctl disable ufw
sudo systemctl stop ufw
sudo systemctl disable iptables
sudo systemctl stop iptables
sudo systemctl disable firewalld
sudo systemctl stop firewalld

