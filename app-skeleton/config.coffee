
###
	Application Cofiguration
###

module.exports =
	
	title: 'My Application'
	language: 'en-US'
	encoding: 'utf-8'
	rawNotifications: off
	raw404: off

	session:
		loginUrl: '/login'
		guestSessions: off
		regenInterval: 5 * 60
		permanentExpires: 30 * 24 * 3600
		temporaryExpires: 24 * 3600
		guestExpires: 7 * 24 * 3600

	regex: {}

	headers:
		'Content-Type': (req, res) -> "text/html; charset=#{@config.encoding}"
		'Date' : -> new Date().toUTCString()
		'Status': (req, res) -> "#{res.statusCode} #{@httpStatusCodes[res.statusCode]}"
		'X-Powered-By': 'NodeJS/' + process.version

	server:
		strictRouting: off
		headRedirect: off
		maxFieldSize: 2 * 1024 * 1024
		maxUploadSize: 2 * 1024 * 1024
		keepUploadExtensions: on
		uploadDir: 'private/incoming/'
		
	staticServer:
		eTags: on
		acceptRanges: on
		indexFile: 'index.html'
		
	cacheControl:
		maxAge: 10 * 365 * 24 * 60 * 60
		static: 'public'
		dynamic: 'private, must-revalidate, max-age=0'
		error: 'no-cache'