#!/usr/bin/env bash

shopt -s globstar

sudo echo sudo access granted

declare -A scripts

scriptFiles=(./scripts/**/script.sh)

for scriptFile in "${scriptFiles[@]}"
do
  withoutPath=${scriptFile#"./scripts/"}
  scriptName=${withoutPath%"/script.sh"}
  
  scripts[${scriptName}]=${scriptFile}
done

for KEY in "${!scripts[@]}"; do
  # Print the KEY value
  echo "Key: $KEY"
  # Print the VALUE attached to that KEY
  echo "Value: ${scripts[$KEY]}"
done
