#!/usr/bin/env python

import os, status, time

def main():
	pids = status.getServerPids()
	if len(pids):
		status.serverAlreadyRunning(pids, 'Unable to start server. It is already running')
	else:
		cmd = 'nohup coffee production.coffee > server.log 2>&1&'
		os.popen(cmd)
		time.sleep(0.5)
		buf = open('server.log','r').read()
		print buf

if __name__ == '__main__':
	main()