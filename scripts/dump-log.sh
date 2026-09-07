#!/usr/bin/env bash
# Streams the tweak's log lines from the iPhone plugged into this Mac. Ctrl-C stops it.
#
#   scripts/dump-log.sh > out/spotifyglass.log     # then kill and relaunch Spotify on the phone
#   scripts/dump-log.sh -n                         # over Wi-Fi
#
# The hierarchy dumps arrive as numbered parts ("now playing hierarchy 3/9").
exec idevicesyslog -p Spotify -m spotifyglass "$@"
