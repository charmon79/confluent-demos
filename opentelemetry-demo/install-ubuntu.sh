#!/bin/bash

wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.83.0/otelcol-contrib_0.83.0_linux_amd64.deb
dpkg -i otelcol-contrib_0.83.0_linux_amd64.deb
systemctl restart otelcol-contrib.service

# default config file: /etc/otelcol-contrib/config.yaml
# environment file (defines location of config file): /etc/otelcol-contrib/otelcol.conf

# start: systemctl start otelcol-contrib.service
# stop: systemctl stop otelcol-contrib.service
# logs: journalctl -r -u otelcol-contrib.service -b
