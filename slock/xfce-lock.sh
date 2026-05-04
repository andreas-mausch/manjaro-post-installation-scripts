#!/bin/bash

ssh-add -D 2>/dev/null
gpgconf --kill gpg-agent 2>/dev/null

xset dpms force suspend 2>/dev/null

# It is important to start slock non-blocking, otherwise
# XFCE waits until this script finishes before it suspends
# the laptop.
# This is explicitly not recommended by ChatGPT (race conditions,
# slock might not be running in foreground, user can be unprotected
# with bad timing), but it solves my problem good enough.
nohup slock >/dev/null 2>&1 &
