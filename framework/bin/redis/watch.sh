#!/bin/sh

# Redis log watch script

watch --interval 1 'tail -n 20 log/redis.log'