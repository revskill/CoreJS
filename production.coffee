
# Production Server
# =================

CFramework = require './common'

CFramework::configure 'environment', 'PRODUCTION'

CFramework::configure 'server'
	listenPort: 8080
	multiProcess: on
	stayUp: on

CFramework::on 'app_init', (app) ->

	# Application Initialization
	
	app.on 'init', -> @use 'listenport-ignore'
	
	app.debugMode = off
	app.viewCaching = on
	app.responseCaching = on
	app.baseUrl = "http://#{app.domain}"
	
CFramework::on 'init', -> # Environment Initialization

new CFramework()