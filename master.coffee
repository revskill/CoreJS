
# Development Server
# ==================

CFramework = require './common'

CFramework::configure 'environment', 'DEVELOPMENT'

CFramework::configure 'server'
	listenPort: 8080
	multiProcess: off
	stayUp: off

CFramework::on 'app_init', (app) ->
	
	# Application Initialization
	
	app.debugMode = off
	app.viewCaching = off
	app.responseCaching = off

CFramework::on 'init', -> # Framework Initialization
	
new CFramework()