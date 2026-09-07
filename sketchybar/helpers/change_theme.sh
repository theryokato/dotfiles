#!/bin/bash

XDG_CONFIG_HOME=~/.config

if [[ -d "${XDG_CONFIG_HOME}/sketchybar_origin" && -d "${XDG_CONFIG_HOME}/sketchybar" ]]; then
  # If sketchybar_origin and sketchybar exist, switch to sketchybar_bracket
  mv "${XDG_CONFIG_HOME}/sketchybar" "${XDG_CONFIG_HOME}/sketchybar_bracket"
  mv "${XDG_CONFIG_HOME}/sketchybar_origin" "${XDG_CONFIG_HOME}/sketchybar"
  echo "Switched to sketchybar_bracket configuration."
elif [[ -d "${XDG_CONFIG_HOME}/sketchybar_bracket" && -d "${XDG_CONFIG_HOME}/sketchybar" ]]; then
  # If sketchybar_bracket and sketchybar exist, switch to sketchybar_origin
  mv "${XDG_CONFIG_HOME}/sketchybar" "${XDG_CONFIG_HOME}/sketchybar_origin"
  mv "${XDG_CONFIG_HOME}/sketchybar_bracket" "${XDG_CONFIG_HOME}/sketchybar"
  echo "Switched to sketchybar_origin configuration."
else
  echo "Error: Required directories are missing or in an invalid state."
  exit 1
fi

# Reload sketchybar
/opt/homebrew/bin/sketchybar --reload
