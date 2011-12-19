#!/usr/bin/env python

import os, status, time

def main():
	pids = status.getServerPids()
	if ( len(pids) ):
		plural = "s" if len(pids) > 1 else ''
		pids = " ".join(pids)
		cmd = "kill %s >/dev/null 2>&1; kill -9 %s >/dev/null 2>&1" % (pids, pids)
		output = os.popen(cmd)
		check = status.getServerPids()
		if len(check): check = status.getServerPids() # extra check, just to be sure
		if len(check):
			print "\nUnable to stop Redis Server with PID%s \033[0;31m%s\033[0m\n" % (plural, pids)
		else:
			print "\n\033[0;31mRedis Server stopped\033[0m\n"
	else:
		print "\n\033[0;31mRedis Server is not running\033[0m\n"
	
if __name__ == '__main__':
	main()