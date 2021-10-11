#!/bin/bash

git clone https://${USER}:${CI_PUSH_TOKEN}@gitlab.demlabs.net/cellframe/cellframe-dashboard.git
cd cellframe-dashboard
git remote set-url origin https://${USER}:${CI_PUSH_TOKEN}@gitlab.demlabs.net/cellframe/cellframe-dashboard.git

git checkout support-4958

versionPatch=$(cat config.pri | grep 'VER_PAT =' | cut -d'=' -f 2)
let "versionPatch++"
echo "update version patch to $versionPatch"
sed -i "s/VER_PAT = \"[0-9]\+\"/VER_PAT = \"$versionPatch\"/g" config.pri


git add config.pri
git commit -m 'update version patch'
git push
