#!/bin/bash

. ~/.local/bin/env/configureJvmEnv.sh

echo -e "\n\nListing software versions:"

echo -e "\nOpenVSCode Server: "
grep version ~/.local/openvscode-server/latest/package.json