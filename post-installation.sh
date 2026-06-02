#!/usr/bin/env bash

set -e

shopt -s globstar

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Updating pacman database.."
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

  if [ -z "${scriptFile}" ];
  then
    log "ERROR: Couldn't find script '${argument}'"
    exit 1
  fi

  log "Starting: ${argument}"

  folder=$(dirname ${scriptFile})
  filename=$(basename ${scriptFile})
  cd ${folder}
  bash -e ${filename}
  cd - > /dev/null

  log "Finished: ${argument}"
done

log "All scripts completed successfully"
