#!/usr/bin/env python

import os, sys, re

def main(notRunning='Server is not running'):
	pids = getServerPids()
	if ( len(pids) ):
		serverAlreadyRunning(pids)
	else:
		print "\n\033[0;31m%s\033[0m\n" % notRunning

def serverAlreadyRunning(pids, msg='Server is running'):
	plural = 's' if len(pids) > 1 else ''
	pids = " ".join(pids)
	print "\n%s with PID%s: \033[0;31m%s\033[0m\n" % (msg, plural, pids)

def getServerPids():
	buf = os.popen('ps ax | grep node | grep -v grep').read().strip()
	pids = []
	if ( len(buf) ):
		buf = buf.split('\n')
		regex = re.compile('^\d+:\d+:(\d+)\s+' if sys.platform is 'darwin' else '^(\d+)\s+')
		for proc in buf:
			match = regex.match(proc.strip())
			if match is not None:
				pids.append(match.groups()[0])
	return pids
	
if __name__ == '__main__':
	main()