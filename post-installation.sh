#!/usr/bin/env bash

set -e

shopt -s globstar

echo "Updating pacman database.."
sudo pacman -Sy

declare -A scripts

scriptFiles=(./**/script.sh)

for scriptFile in "${scriptFiles[@]}"
do
  withoutPath=${scriptFile#"./"}
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
  bash -e ${filename}
  cd - > /dev/null
done
