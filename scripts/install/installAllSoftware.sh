#!/bin/bash

set -euo pipefail

DIR_ME=$(realpath $(dirname $0))
. ${DIR_ME}/.installUtils.sh
setUserName "$(whoami)"

bash ${DIR_ME}/../config/system/prepareXServer.sh ${USERNAME}

echo -e "\n\nInstalling OpenVSCode Server"
bash ${DIR_ME}/installOpenVSCodeServer.sh

echo -e "\n\nInstalling OpenJDK 11 via apt..."
bash ${DIR_ME}/installOpenjdk.sh

# clean-up
sudo apt autoremove

bash ${DIR_ME}/../report/listVersions.sh
