#!/bin/sh

# Server log watch script

watch --interval 1 'tail -n 20 server.log'

