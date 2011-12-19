#!/usr/bin/env python

import os, status, time

def main():
	pids = status.getServerPids()
	if len(pids):
		status.serverAlreadyRunning(pids, 'Unable to start Redis Server. It is already running')
	else:
		cmd = 'redis-server config/redis.conf'
		buf = os.popen(cmd).read();
		if ( len(buf) == 0 ):
			print '\nRedis Server started\n'
		else:
			print buf

if __name__ == '__main__':
	main()