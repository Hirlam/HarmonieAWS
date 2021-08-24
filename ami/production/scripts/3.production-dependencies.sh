#!/usr/bin/env bash

install_ecflow() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -q \
    ecflow-server \
    ecflow-client \
    perl
}

fix_x11_forward() {
  echo 'X11Forwarding yes' | sudo tee -a /etc/ssh/sshd_config > /dev/null
}

# ------------------------------------------------------------------------------
main() {
  install_ecflow
  fix_x11_forward
}

main "${@}"
# ------------------------------------------------------------------------------

