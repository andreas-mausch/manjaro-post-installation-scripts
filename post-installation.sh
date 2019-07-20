#!/usr/bin/env bash

set -e

shopt -s globstar

sudo echo sudo access granted

# Update the pacman database
echo "Updating pacman database.."
sudo pacman -Syy

declare -A scripts

scriptFiles=(./scripts/**/script.sh)

for scriptFile in "${scriptFiles[@]}"
do
  withoutPath=${scriptFile#"./scripts/"}
  scriptName=${withoutPath%"/script.sh"}
  
  scripts[${scriptName}]=${scriptFile}
done

for argument in "$@"
do
  scriptFile=${scripts[$argument]}
  echo "Executing ${argument}"

  if [ -z "${scriptFile}" ];
  then
    echo "ERROR: Couldn't find script ${argument}"
    exit 1
  fi

  folder=$(dirname ${scriptFile})
  filename=$(basename ${scriptFile})
  cd ${folder}
  source ${filename}
done
