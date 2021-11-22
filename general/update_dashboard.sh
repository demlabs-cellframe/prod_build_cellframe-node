#!/bin/bash

git clone https://${USER}:${CI_PUSH_TOKEN}@gitlab.demlabs.net/cellframe/cellframe-dashboard.git
cd cellframe-dashboard
git remote set-url origin https://${USER}:${CI_PUSH_TOKEN}@gitlab.demlabs.net/cellframe/cellframe-dashboard.git
git checkout master
git submodule init
git submodule update

versionPatch=$(cat config.pri | grep 'VER_PAT =' | cut -d'=' -f 2)
echo "version patch = $versionPatch"
let "versionPatch++"
echo "update version patch to $versionPatch"
sed -i "s/VER_PAT = [0-9]\+/VER_PAT = $versionPatch/g" config.pri

#update cellframe-node

cd cellframe-node && git checkout master && git pull && cd -

git add config.pri cellframe-node
git commit -m 'update version patch'
git push
