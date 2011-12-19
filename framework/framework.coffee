# # CFramework
# <hr/><br/>
#
# Master class in charge of assembling the applications together, and loading the required
# dependency libraries used thorough the application
#
# Available globally as **framework**
# 
# **@extends** EventEmitter
# <hr/>

events = require 'events'

class CFramework extends events.EventEmitter
	
	clusterConfig = null
	
	apps: {}
	vhosts: {}
	config: {}
	path: __dirname
	
	modules:
		events: events
		coffee: require 'coffee-script'
		http: require 'http'
		path: require 'path' 
		util: require 'util' 
		cluster: require 'cluster' 
		url: require 'url' 
		fs: require 'fs' 
		os: require 'os'
		file: require 'file' 
		qs: require 'qs' 
		mime: require 'mime' 
		crypto: require 'crypto'
		bcrypt: require 'bcrypt'
		formidable: require 'formidable' 
		redis: require 'redis' 
		mysql: require 'mysql' 
		node_uuid: require 'node-uuid' 
		discount: require 'discount' 
		sanitizer: require 'sanitizer'
		noxmox: require 'noxmox'
		nodemailer: require 'nodemailer'

	# Framework regular expressions. Extended by each application. 
	# These regexes can't be overridden by the application.
	
	regex:
		relPath: /^\.\//
		absPath: /^\//
		isPath: /\//g
		jsFile: /\.(js|coffee)$/
		tplFile: /\.tpl$/
		dotFile: /^\./
		singleParam: /^\/([a-z0-9\-:]+)?$/i
		fileWithExtension: /\.[a-z]+$/i
		htmlFile: /\.htm(l)?$/i
		hasSlash: /\//g
		multipleSlashes: /\/+/g
		startsWithSlash: /^\//
		restrictedView: /^#\/?/
		layoutView: /^@\/?/
		startsWithUnderscore: /^_/
		startOrEndSlash: /(^\/|\/$)/g
		startOrEndRegex: /(^\^|\$$)/g
		endsWithSlash: /\/$/
		regExpChars: /(\^|\$|\\|\.|\*|\+|\?|\(|\)|\[|\]|\{|\}|\||\/)/g
		controllerAlias: /^\/(.*?)\//
		dateFormat: /[a-z]{3} [a-z]{3} \d{2} \d{4} \d{2}:\d{2}:\d{2}/i
		acceptsGzip: /\,?gzip\,?/
		headerFilter: /^__([a-z][a-z-]+[a-z])__$/
		getMethod: /^(GET)$/
		postMethod: /^(POST)$/
		getPostMethod: /^(GET|POST)$/
		partialView: /^_(.*?)+(\.tpl)$/i
		partialViewReplace: /(^\/)?([a-z0-9\-_\/]+)\/(.*)$/i
		
		integer: /^[0-9]+$/
		float: /^\d+\.\d+$/
		number: /^\d+(\.\d+)?$/
		null: /^null$/i
		boolean: /^(true|false)$/i
		binary: /^(0|1)$/
		digit: /^\d$/
		alpha: /^[a-zA-Z]+$/
		alpha_spaces: /^[a-zA-Z ]+$/
		alpha_dashes: /^[a-zA-Z\-]+$/
		alpha_underscores: /^[a-zA-Z_]+$/
		alpha_spaces_underscores: /^[a-zA-Z _]+$/
		alpha_dashes_underscores: /^[a-zA-Z\-_]+$/
		alpha_lower: /^[a-z]+$/
		alpha_lower_spaces: /^[a-z ]+$/
		alpha_lower_dashes: /^[a-z\-]+$/
		alpha_lower_underscores: /^[a-z_]+$/
		alpha_lower_spaces_underscores: /^[a-z _]+$/
		alpha_lower_dashes_underscores: /^[a-z\-_]+$/
		alpha_upper: /^[A-Z]+$/
		alpha_upper_spaces: /^[A-Z ]+$/
		alpha_upper_dashes: /^[A-Z\-]+$/
		alpha_upper_underscores: /^[A-Z_]+$/
		alpha_upper_spaces_underscores: /^[A-Z _]+$/
		alpha_upper_dashes_underscores: /^[A-Z\-_]+$/
		alnum: /^[a-zA-Z0-9]+$/
		alnum_spaces: /^[a-zA-Z0-9 ]+$/
		alnum_dashes: /^[a-zA-Z0-9\-]+$/
		alnum_underscores: /^[a-zA-Z0-9_]+$/
		alnum_spaces_underscores: /^[a-zA-Z0-9 _]+$/
		alnum_dashes_underscores: /^[a-zA-Z0-9\-_]+$/
		alnum_lower: /^[a-z0-9]+$/
		alnum_lower_spaces: /^[a-z0-9 ]+$/
		alnum_lower_dashes: /^[a-z0-9\-]+$/
		alnum_lower_underscores: /^[a-z0-9_]+$/
		alnum_lower_spaces_underscores: /^[a-z0-9 _]+$/
		alnum_lower_dashes_underscores: /^[a-z0-9\-_]+$/
		alnum_upper: /^[A-Z0-9]+$/
		alnum_upper_spaces: /^[A-Z0-9 ]+$/
		alnum_upper_dashes: /^[A-Z0-9\-]+$/
		alnum_upper_underscores: /^[A-Z0-9_]+$/
		alnum_upper_spaces_underscores: /^[A-Z0-9 _]+$/
		alnum_upper_dashes_underscores: /^[A-Z0-9\-_]+$/
		white_space: /s+/g
		variable: /^[a-zA-Z][a-zA-Z0-9_]+$/
		anything: /.+/
		url: /(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:~\+#]*[\w\-\@?^=%&amp;~\+#])?/
		email: /[_a-zA-Z0-9-"'\/]+(\.[_a-zA-Z0-9-"'\/]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.(([0-9]{1,3})|([a-zA-Z]{2,3})|(aero|coop|info|museum|name))/
		password: /^.{6,30}$/
		md5_hash: /^[a-fA-F\d]{32}$/
	
	constructor: ->

		global.framework = @
		
		@className = @constructor.name
		
		@environment = @config['environment'] or 'GENERIC'

		@masterPath = process.cwd()

		require './global'

		clusterConfig =
			listenPort: null
			multiProcess: 0
			masterProcess: 'node [master]'
			singleProcess: 'node [single process]'
			workerProcess: 'node worker'

		@serverOptions = null

		@classes = 
			CFramework: @constructor
			CApplication: require './application'
			CUtility: require './utility'
		
		@mailer = createMailServer @config['mailer']
		
		@util = new @classes.CUtility this
		@util.requireAllTo "#{@path}/classes", @classes
		
		require './response'
		require './request'
		
		injectApplicationGlobals()
		
		addVhosts @config['vhosts']
		
		@emit 'init'

		@startServer();

	# ## configure
	#
	# 	(context, value)
	# 
	# Configures the framework.
	#
	# **@param string context**<br/>
	# Context to apply the configuration to. Accessible via framework.config[context]<br/>
	# **@param string | object value**<br/>
	# Value to apply to the framework configuration<br/>
	# **@static**
	# <hr/>

	configure: (context, value) -> 
		unless @config[context]?
			# Create new configuration context if new
			@config[context] = value
		else
			# If exists, extend configuration context
			{extend} = require 'underscore'
			extend @config[context], value
			
			console.log @config[context]; process.exit()

	# ## require
	#
	# 	(module)
	#
	# Requires a module frow within the framework's namespace
	# 
	# **@param string module**<br/>
	# Name of the module to require<br/>
	# **@returns**<br/>
	# The contents of the required module
	# <hr/>

	require: (module) ->
		require module

	# ## startServer
	# 
	# 	()
	# 
	# Creates the master server, which handles and routes the
	# requests to the application associated with it.
	# 
	# **@private**
	# <hr/>

	startServer: () ->
		options = @config['server']
		{cluster, os} = @modules
		@serverOptions = options = _.extend clusterConfig, options
		apps = framework.apps
		vhosts = framework.vhosts
		defaultHost = vhosts[_.keys(framework.vhosts)[0]] # Application Servers
		allCPUS = os.cpus()
		
		# Multi Process
		if typeof options.multiProcess is 'number'
			allCPUS = options.multiProcess or 1
			options.multiProcess = true
		else
			allCPUS = os.cpus().length
	
		requestHandler = (req, res) ->
			unless req.headers.host? then req.headers.host = ''
			host = vhosts[hostAddr = req.headers.host.split(':')[0]]
			if host?
				if req.url is '/favicon.ico' and req.method is 'GET'
					apps[host.domain].emit 'favicon_request', req, res
					return if req.__stopRoute is true
					res.end ''
				else
					host.emit 'request', req, res # Event triggered on the application's server
			else
				# Vhost not handled by server, redirect to defaultApp's homeUrl
				defaultApp = framework.defaultApp
				req.__stopRoute = true  # stop route manually
				defaultApp.routeRequest req, res
				res.redirect defaultApp.url()
			null

		commonStartupOperations = ->
			if options.stayUp then process.on 'uncaughtException', (e) -> console.trace "[#{framework.defaultApp.date()}] CRITICAL SERVER ERROR - #{e.toString()}"
			@emit 'server_start', options
			startupMessage.call this, options
			@emit 'startup_message'
			app.emit 'init' for domain,app of @apps

		interProcess = this

		if options.multiProcess and cluster.isMaster
			
			# Setup workers
			
			process.title = options.masterProcess
			
			for cpu in [0...allCPUS]
				worker = cluster.fork()
				worker.on 'message', (data) ->
					# Worker -> Master
					interProcess.emit 'worker_message', (data) if data.cmd?
					worker.send {response: data.response} if data.response?  # Acknowledge to worker
				
			cluster.on 'death', (worker) ->
				console.log "#{framework.defaultApp.date()} - Worker process #{worker.pid} died. Restarting..."
				cluster.fork()
				
			commonStartupOperations.call this
			
			console.log "\n#{framework.defaultApp.date()} - Master running..."

		else
		
			server = @modules.http.createServer requestHandler
			server.listen options.listenPort
			
			if options.multiProcess
				process.title = options.workerProcess
				console.log "#{framework.defaultApp.date()} - Worker running..."
			else
				process.title = options.singleProcess
				commonStartupOperations.call this
				autoCurlRequest()
			
	
	# ## onAppEvent
	# 
	# 	(event, callback)
	# 
	# Attaches a callback to all the application's events
	# 
	# **@param event** <br/> 
	#  Event <br/>
	# **@param Function callback** <br/>
	# Callback to attach <br/>
	# **@returns** <br/>
	# Framework instance for chaining <br/>
	# <hr/>

	onAppEvent: (event, callback) ->
		@apps[host].on event, callback for host of @apps
		this


	# <!-- ============================================================================================ -->
	# # Private Functions
	# <!-- ============================================================================================ -->

	
	# ## startupMessage
	# 
	# 	(options)
	# 	
	# Prints the server's startup message
	# 	
	# **@inner**
	# <hr/>
	
	startupMessage = (options) ->
		{os} = framework.modules
		workerStr = if options.multiProcess then "running #{os.cpus().length} workers" else '(Single process)'
		console.log "\nStarted #{@environment} Server #{workerStr}\n\nVirtual Hosts:\n--------------"
		portStr = if options.listenPort isnt 80 then ":#{options.listenPort}" else ''
		for host of framework.vhosts
			console.log "http://#{host}#{portStr}" unless host is 'default'
		console.log ''
	

	# ## addVhosts
	# 
	# 	(servers)
	# 
	# Creates the application instances and assigns them to framework.apps
	# 
	# **@inner**
	# <hr/>
	
	addVhosts = (servers) ->
		for host, data of servers
			path = framework.modules.path.normalize "#{framework.masterPath}/#{data.path}"
			Application = require "#{path}/app" # no slash required
			
			framework.currentDomain = host # Start code injection
			framework.classes.CController::queuedRoutes[host] = []
			
			app = new Application(host, path)
			
			framework.vhosts[host] = app.createServer()
			framework.vhosts.default = framework.vhosts[host] unless framework.vhosts.default?
			initFunction = app.require 'init'
			initFunction(app)
			framework.defaultApp = app unless framework.defaultApp?
			
		delete framework.currentDomain # stop code injection
		null
	
	
	# ## createMailServer
	# 
	# 	(config)
	# 
	# Creates the mail server based on framework.config.mailer
	# 
	# **@inner**
	# <hr/>
	
	createMailServer = (config) ->
		errMsg = "\nInvalid configuration for 'mailer'.\n"
		if config is 'sendmail' or typeof config is 'string'
			method = 'sendmail'
		else if typeof config is 'object'	
			if 'host' of config
				method = 'SMTP'
			else if 'AWSAccessKeyID' of config
				# Use SES
				method = 'SES'
			else
				console.log errMsg; process.exit()
		else
			console.log errMsg; process.exit();
			
		framework.modules.nodemailer[method] = config
		
		framework.modules.nodemailer.send_mail


	# ## autoCurlRequest
	# 
	# 	()
	# 
	# Process argv to detect if an automatic curl request should be performed (exit afterwards)
	# 
	# **@inner**
	# <hr/>
		
	autoCurlRequest = ->
		if process.argv.length >= 3
			{exec} = require 'child_process'
			args = process.argv[2..]
			url = args[args.length-1]
			portStr = if framework.config.server.listenPort isnt 80 then ":#{framework.config.server.listenPort}" else ''
			url = "http://#{framework.defaultApp.domain}#{portStr}#{url}" if framework.regex.startsWithSlash.test url
			switches = args[...args.length-1].join(' ')
			exec "curl #{switches} #{url}", (err, stdout, stderr) -> 
				if err then console.log stderr else console.log stdout
				process.exit();
		null
	
	
	# ## injectApplicationGlobals
	# 
	# 	()
	# 
	# Makes app available as a global within the app's classes and controllers
	# 
	# **@inner**
	# <hr/>

	injectApplicationGlobals = ->
		fs = framework.modules.fs
		coffee = framework.modules.coffee
		coffeeExtensionHandler = require.extensions['.coffee']
		require.extensions['.coffee'] = (module, filename) ->
			unless framework.currentDomain?
				coffeeExtensionHandler.call this, module, filename
			else
				globals = "app = framework.apps['#{framework.currentDomain}']\n"
				globals += framework.apps[framework.currentDomain].injectGlobals if framework.apps[framework.currentDomain].injectGlobals?
				content = fs.readFileSync(filename, 'utf8')
				content = coffee.compile "#{globals}\n#{content}", {filename}
				module._compile content, filename
	
	
module.exports = CFramework

# <br/>