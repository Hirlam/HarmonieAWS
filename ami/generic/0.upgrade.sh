#!/usr/bin/env bash

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q
dpkg --print-architecture |grep arm64 && sudo apt install libc6-lse
sudo reboot
