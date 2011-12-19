
# # CApplication
# <hr/>
# 
# Available globally (on a per-application basis) as **app**
#
# **@uses**
#
# - [mime](https://github.com/bentomas/node-mime)
# - [qs](https://github.com/visionmedia/node-querystring)
# - [file](https://github.com/mikeal/node-utils)
# 
# **@extends** EventEmitter

{EventEmitter} = require 'events'
{exec} = require 'child_process'

class CApplication extends EventEmitter

	debugMode: off
	debugColor: '0;37'
	globals: {}
	injectGlobals: null
	initialize: null
	portStr: ''
	purgeCachesOnStartup: ['response_cache']
	mvcMethods: ['GET', 'POST']
	otherMethods: ['OPTIONS', 'PUT', 'DELETE', 'TRACE', 'CONNECT']
	
	# ## constructor
	# 
	# 	(@domain, @path)
	# 
	# Creates the application instance, and initializes any local libraries for
	# the application.
	# 
	# All of the classes on /private/classes will be instantiated and made local properties
	# of the application.
	# 
	# **@param domain Domain** <br/>
	#  for the application <br/>
	# **@param path**  <br/>
	#  Path to the application <br/>
	# **@constructor**
	# <hr/>
	
	constructor: (@domain, @path) ->
		
		@className = @constructor.name
		
		framework.apps[@domain] = this  # make app available early
		
		@config = require "#{@path}/config"
		
		# Configuration properties
		@viewCaching = off
		@responseCaching = off

		framework.emit 'app_init', this
		
		# REDIS Configuration
		@config.redis = _.extend {}, framework.config.common_config.redis
		@config.redis = _.extend @config.redis, framework.config.vhosts[@domain].redis
		
		# MYSQL Configuration
		@config.mysql = _.extend {}, framework.config.common_config.mysql
		@config.mysql = _.extend @config.mysql, framework.config.vhosts[@domain].mysql
		
		# Port string & BaseUrl
		listenPort = framework.config.server.listenPort
		portStr = if listenPort isnt 80 then ":#{listenPort}" else ''
		@baseUrl = "http://#{@domain}#{portStr}"
		
		@modules = _.extend {}, framework.modules # Extend framework modules
		@regex = _.extend @config.regex, framework.regex # Extend framework regexes 
		@regexKeys = (key for key of @regex)
		
		@routes = {}
		@relPaths = {}
		@controllers = {}
		
		# Class constructor functions, for all the classes inside private/classes
		
		@constructors =
			classes: {}
			controllers: {}

		# Require the application's classes
		framework.util.requireAllTo "#{@path}/private/classes", @constructors.classes
		
		# Status codes reference
		@httpStatusCodes = framework.modules.http.STATUS_CODES
		
		# Create the application's controllers
		for file in framework.util.getFiles "#{path}/private/controllers"
			className = file.replace @regex.jsFile, ''
			controllerClass = require "#{path}/private/controllers/#{className}"
			@constructors.controllers[className] = controllerClass
			@controllers[className] = new controllerClass this
		
		# Views
		@partialViews = {}
		@views =
			static: []
			buffers: {}
			callbacks: {}
			
		# Add static views
		@views.static = framework.util.ls "#{@path}/private/views", @regex.tplFile
		
		# Static Server regex. This RegExp is calculated on startup, it is not updated on real time
		@staticIgnores = []
		regex = '^\\/('
		indexFileEnabled = typeof @config.staticServer.indexFile is 'string'
		for dir, i in getStaticDirs.call(this)
			
			if indexFileEnabled
				# If a static view exists, ignore the path
				@staticIgnores.push("/#{dir}/") if "#{dir}.tpl" in @views.static
			
				# If a controller exists with the directory name, ignore it
				continue if framework.util.toCamelCase("#{dir}-controller") of @controllers
			
			path = dir.replace(@regex.startOrEndSlash, '').replace(@regex.regExpChars, '\\$1')
			path = "|#{path}" if i > 0
			regex += path
		regex += ')\\/'
		@staticFileRegex = new RegExp regex
		
		# MySQL Client
		@mysqlClient = @modules.mysql.createClient @config.mysql
		
		# MySQL Check
		exec 'mysql status', (err, stdout, stderr) => if /ERROR 2002/.test(stderr) then @log 'ABORT: MySQL server is not running.\n'; process.exit();
		
		# REDIS Configuration
		@redisOptions = @config.redis.clientOptions or {parser: 'hiredis', return_buffers: false} # Optionally override redis client options
		@redisClients = {}
		redisOnReady = (storage, dbIndex) => @redisClients[storage].select dbIndex, (err, res) => 
			if err then @log "Unable to select Redis dbIndex #{dbIndex}: #{err.toString()}\n"; process.exit()
			@purgeRedisCache.apply(this, @purgeCachesOnStartup) if storage is 'cacheStore' and @responseCaching is on
			@emit "redis_client_loaded", storage
		redisOnError = (err) => @emit 'redis_error', err
		
		# REDIS Session Store
		@redisClients['sessionStore'] =  framework.modules.redis.createClient @config.redis.port, @config.redis.host, @redisOptions
		@redisClients['sessionStore'].on 'ready', => redisOnReady.call this, 'sessionStore', @config.redis.sessionStore
		@redisClients['sessionStore'].on 'error', redisOnError
		
		# REDIS Cache Store
		@redisClients['cacheStore'] =  framework.modules.redis.createClient @config.redis.port, @config.redis.host, @redisOptions
		@redisClients['cacheStore'].on 'ready', => redisOnReady.call this, 'cacheStore', @config.redis.cacheStore
		@redisClients['cacheStore'].on 'error', redisOnError

		# Redis Check
		exec 'ps aux | grep redis-server | grep -v grep', (err, stdout) => 
			if (process.platform is 'darwin' and stdout is '') or (process.platform is 'linux' and err isnt null)
				@log 'ABORT: Redis server is not running.\n'
				process.exit();
			null
		
		# Controller
		@controller = @controllers.MainController

		# Database
		@db = @createClassInstance 'Database'

		# Session
		@session = @createClassInstance 'Session'

		# CSRF Protection
		@csrf = @createClassInstance 'CSRFProtect'
		
		# Markdown
		@markdown = @createClassInstance 'Markdown'
		
		# Template
		@template = @createClassInstance 'Template'
		
		# View
		@createClassInstance 'View'

		# Amazon Web Storage
		@aws = @createClassInstance 'AmazonS3'
		
		# Mailer
		@mailer = @createClassInstance 'Mailer'
		
		# Blowfish
		@blowfish = @createClassInstance 'Blowfish'

		# Instantiate any extra classes
		instantiateExtraClasses.call this
		
		# Build Partial Views
		buildPartialViews.call this
		
		# Initialization event
		@emit 'init'
		
		# Run initialize method if available
		@initialize?()
	
	# ## require
	# 
	# 	(module)
	# 
	# Requires a module relative to the application.
	# 
	# **@param module**  <br/>
	#  Module to require <br/>
	# **@returns** <br/>
	# The required module
	# <hr/>

	require: (module) ->
		try
			require "#{@path}/node_modules/#{module}"  # Try loading module from the local node_modules directory within app/
		catch e
			module = module.replace @regex.relPath, ''
			require "#{@path}/#{module}"  # Load the module relative to the application's path


	# ## use
	# 
	# 	(component, options)
	# 
	# Loads an application component, located in /private/components/{module-name}.coffee
	# 
	# **@param component** <br/>
	#  Name of the component.
	# <hr/>

	use: (component, options) ->
		path = "#{@path}/private/components/#{component}.coffee"
		if @modules.path.existsSync path
			callback = require path
		else
			path = "#{framework.path}/components/#{component}.coffee"
			throw new Error "Component can't be found: #{component}" unless @modules.path.existsSync path
			callback = require path
		callback.call null, this, options


	# ## routeRequest
	# 
	# 	(req, res)
	# 
	# Routes an application request, and determines which controller to use for the route.
	# 
	# **@param req** <br/>
	#  HTTP Request  <br/>
	# **@param res** <br/>
	#  HTTP Response  <br/>
	# **@private**
	# <hr/>

	routeRequest: (req, res) ->
		
		urlData = parseUrl req.url
		url = urlData.pathname
		res.__app = req.__app = this
		res.__request = req
		res.__setCookie = []
		res.__sentHeaders = null
		req.__response = res
		req.__route = {}
		req.__urlData = urlData
		req.__params = {}
		req.__session = {}
		req.__isAjax = req.__isStatic = null
		res.__headers = _.extend {}, @config.headers
		
		@emit 'request', req, res
		
		return if req.__stopRoute is true
		
		if req.method is 'HEAD'
			
			# HTTP Head request
			
			if @listeners('restful_head').length isnt 0
				
				# Attached 'head' event
				
				@emit 'restful_head', req, res
				
			else
			
				# Default 'head' behavior
			
				res.statusCode = 302
				
				if typeof @config.server.headRedirect is 'string'
					location = @url @config.server.headRedirect
				else
					location = @url req.url
				
				res.setHeaders Location: location, Connection: 'close'
				res.sendHeaders()
				res.end()
				req.connection.destroy()
			
		else if req.method is 'GET' and ( @staticFileRegex.test(url) and url not in @staticIgnores ) or @regex.fileWithExtension.test(url)
		
			# Static File Request
			
			if @regex.dotFile.test @modules.path.basename(url) then @notFound res; return # No serving of dot files
			
			req.__isStatic = true
			@emit 'static_file_request', req, res
			
			if req.__stopRoute is true then return # Stop route on 'static_file_request' event
			
			@serveStatic "#{@path}/docroot#{url}", req, res
			
		else if req.method in @mvcMethods
		
			# MVC Request
			
			if req.__stopRoute is true then return # Stop route (early)

			@emit 'pre_mvc_request', req, res
			
			if req.__stopRoute is true then return # Stop route on 'pre_mvc_request' event
			
			@emit 'pre_mvc_get', req, res if req.method is 'GET'
			@emit 'pre_mvc_post', req, res if req.method is 'POST'
			
			if req.__stopRoute is true then return # Stop route on 'pre_mvc_get' or 'pre_mvc_post' event
			
			if framework.util.isTypeOf(req.__urlData.query, 'string')
				queryData = @modules.qs.parse req.__urlData.query
				req.__isAjax = true if queryData.ajax? and parseInt(queryData.ajax) is 1
				delete queryData.ajax
				req.__queryData = queryData
				
			else
				req.__queryData = {}

			url = req.__urlData.pathname = req.__urlData.pathname.toLowerCase()  unless @config.server.strictRouting # Only pathname is converted to lowercase. Query params remain untouched
			
			# Cookies are loaded upon request

			@emit 'mvc_request', req, res
			@emit 'mvc_get', req, res
			@emit 'mvc_post', req, res
			
			if req.__stopRoute is true then return # Stop route on 'mvc_request' event
			
			if url is '/' or @regex.singleParam.test(url)
				req.__isMainRequest = true
				controller = if url isnt '/' then @controller.getControllerByAlias(url) or @controllers.MainController else @controllers.MainController
				controller.processRoute.call controller, urlData, req, res, @
			else
				req.__isMainRequest = null
				@controller.exec.call @controller, urlData, req, res, @
				
		else if req.method in @otherMethods
			
			# REST Implementation
			
			method = "restful_#{req.method.toLowerCase()}"
			
			# Supported Events: 'restful_options', 'restful_put', 'restful_delete', 'restful_trace', 'restful_connect'
			
			if @listeners(method).length isnt 0
				@emit method, req, res 
			else 
				res.rawHttpMessage 400
			
		else
			
			# Bad Request.
			
			res.rawHttpMessage 400

		null


	# ## createServer
	# 
	# 	(req, res)
	# 
	# Creates the application server.
	# 
	# Note: 	This server doesn't listen, its 'request' event is emitted when the framework
	# routes the request to the application.
	# 		
	# **@param req** <br/> 
	#  HTTP Request <br/>
	# **@param res**  <br/>
	#  HTTP Response <br/>
	# **@private**
	# <hr/>

	createServer: (req, res) ->
		@server = framework.modules.http.createServer((req, res) => @routeRequest req, res )
		@server.domain = @domain
		@server


	# ## serveStatic
	# 
	# 	(path, req, res)
	# 
	# Handles serving of static files
	# 
	# **@param path** <br/>
	#  Path to the static resource <br/>
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response <br/>
	# @private
	# <hr/>

	serveStatic: (path, req, res) ->
		
		# Automatically load index files for static requests, if enabled
		if @regex.endsWithSlash.test(path) and typeof (indexFile = @config.staticServer.indexFile) is 'string'
			path += indexFile
			
		@modules.fs.stat path, callback = (err, stats) =>
			unless err or stats.isDirectory()
				date = new Date()
				now = date.toUTCString()
				lastModified = stats.mtime.toUTCString()
				contentType = @modules.mime.lookup path
				
				maxAge = @config.cacheControl.maxAge
				date.setTime date.getTime() + maxAge * 1000
				expires = date.toUTCString()
				isCached = req.headers['if-modified-since']? and lastModified is req.headers['if-modified-since']
				res.statusCode = 304 if isCached
				
				headers =
					'Content-Type': contentType
					'Cache-Control': "#{@config.cacheControl.static}, max-age=#{maxAge}"
					'Last-Modified': lastModified
					'Content-Length': stats.size
					Expires: expires
					
				acceptRanges = @config.staticServer.acceptRanges
					
				headers['Accept-Ranges'] = 'bytes' if acceptRanges
				
				enableEtags = @config.staticServer.eTags	
					
				if enableEtags is true
					headers['Etag'] = JSON.stringify([stats.ino, stats.size, Date.parse(stats.mtime)].join('-'));
				else if typeof enableEtags is 'function'
					headers['Etag'] = enableEtags stats
					
				if isCached
					@emit 'static_file_headers', req, res, headers, stats, path # Only emit when needed
					res.setHeaders headers
					res.sendHeaders()
					res.end()
				else
				
					streamArgs = [path]
				
					# Process range requests if enabled
				
					if acceptRanges and req.headers.range?
						
						ranges = framework.util.parseRange(stats.size, req.headers.range)
						
						if ranges?
							{start,end} = ranges[0]
							streamArgs.push {start: start, end: end}  # Append options to fs.createReadStream
							len = end - start + 1
							res.statusCode = 206  # 206 Partial Content, http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.2.7
							res.setHeaders 'Content-Range': "bytes #{start}-#{end}/#{stats.size}"
								
						else
							res.rawHttpMessage 416  # 416 Requested Range Not Satisfiable, http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.17
							return  # return early

					stream = @modules.fs.createReadStream.apply null, streamArgs
					
					stream.on 'error', (err) => 
						@serverError res, ["Unable to read #{@relPath(path)}: #{err.toString()}"]
						return  # return early
						
					stream.on 'open', =>
						@emit 'static_file_headers', req, res, headers, stats, path
						res.setHeaders headers
						res.sendHeaders()
						stream.pipe(res)
				null
			
			else
			
				@emit 'static_not_found', path, req, res
				
				return if req.__stopRoute is true
			
				@notFound res # Not a relative path, render 404
			
			null
			
		null

	
	# ## validate
	# 
	# 	(req, fields, onlyCheck)
	# 
	# Validates fields against their validation regexes, and takes necessary action (if needed)
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param object fields**  <br/>
	# Fields to process, containing key/value pairs <br/>
	# **@param boolean onlyCheck** <br/>
	#  If true, returns the result of the validation. Redirects to HTTP/400 Otherwise 
	# <hr/>

	validate: (req, fields, onlyCheck) ->
		msg = regex = param = undefined
		res = req.__response
		route = req.__route
		messages = route.messages
		paramKeys = route.paramKeys
		valid = true
		counter = 0
		if route.validation?
			for param of fields
				fields[param] = _s.trim fields[param]
				if route.validation[param]?
					counter++
					regex = if _.isString(route.validation[param]) and route.validation[param] in @regexKeys then @regex[route.validation[param]] else route.validation[param]
					if regex.test(fields[param])
						fields[param] = framework.util.typecast fields[param]
						continue
					else
						# Cleanup any uploaded files uploaded if validation failed
						req.__invalidParam = [param, fields[param]]
						@controller.cleanupFilesUploaded req.__postData.files, true if req.method is 'POST'
						return false if onlyCheck
						
						if messages? and (messages[param])?
							if typeof messages[param] is 'function'
								msg = messages[param].call this, fields[param]
							else
								msg = messages[param]
						else
							msg = "Invalid: #{fields[param]}"
							
						res.rawHttpMessage 400, msg
						return false
				else
					continue
			
			# Exclude params present in route
			exclude = 0
			exclude++ for key,val of req.__params when val isnt undefined
			
			unless counter is (paramKeys.length-exclude)
				# Cleanup any uploaded files uploaded if validation failed
				@controller.cleanupFilesUploaded req.__postData.files, true if req.method is 'POST'
				return false  if onlyCheck
				res.rawHttpMessage 400, 'Please fill in all the required values'
				false
			else
				valid
		else
			true

	
	# ## url
	# 
	# 	(path)
	# 
	# Returns an application URL, considering the domain and server port
	# 
	# **@param path** <br/>
	#  Path to the application resource <br/>
	# **@returns** <br/>
	#  URL of the application resource <br/>
	# <hr/>
	
	url: (path) ->
		path ?= ''
		"#{@baseUrl}/#{path.replace(@config.regex.startsWithSlash,'').replace(@config.regex.multipleSlashes, '/')}"

	
	# ## login
	# 
	# 	(res)
	# 
	# Redirects to the Login URL (specified in config.session.loginUrl)
	# 
	# **@param res** <br/>
	#  HTTP Response
	# <hr/>

	login: (res) ->
		if res.__controller.constructor.name is 'MainController' and res.__request.__route.path is @config.session.loginUrl
			# Render login view in main
			res.__request.__route.callback.call res.__controller, res.__request, res
		else 
			# Redirect
			res.redirect @config.session.loginUrl


	# ## home
	# 
	# 	(res)
	# 
	# Redirects to the application's Home URL
	# 
	# **@param** <br/>
	#  res HTTP Response
	# <hr/>

	home: (res) ->
		res.redirect "/"

	
	# ## log
	# 
	# 	(context, msg)
	# 
	# Logging facility
	# 
	# **@param context** <br/>
	#  Context to use when logging (optional) <br/>
	# **@param msg** <br/>
	#  Message to log
	# <hr/>

	log: (context, msg) ->
		unless msg?
			console.log "[#{@domain}] - #{@date()} - #{context}"
		else
			console.log "[#{@domain}] - #{@date()} - #{context} - #{msg}"

	# ## debug
	# 
	# 	(context, msg)
	# 
	# Log debug messages, if @app.debugMode is true
	# 
	# [&raquo; Bash Colors Reference](http://paste.pocoo.org/show/467676/)
	# 
	# **@param context** <br/>
	#  Context to use when logging (optional) <br/>
	# **@param msg** <br/>
	#  Message to log
	# <hr/>

	debug: (msg) ->
		return unless @debugMode is on
		console.log "\033[#{@debugColor}m[#{@domain}] - #{@date()} - #{msg}\033[0m"

	# ## relPath
	# 
	# 	(path, offset)
	# 
	# Returns a relative path to the application's directory
	# 
	# **@param path** <br/>
	#  Path to process <br/>
	# **@param offset** <br/>
	#  Offset to use for the returned relative paths <br/>
	# **@returns** <br/>
	#  Relative path, starting from offset (if specified)
	# <hr/>

	relPath: (path, offset) ->
		p = "#{@path}/"
		p += offset.replace(@regex.startOrEndSlash, '') + '/'  unless offset is undefined
		path.replace p, ''
	
	
	# ## fullPath
	# 
	# 	(path)
	# 
	# Returns an absolute path to the application's directory
	# 
	# **@param path** <br/>
	#  Relative path within the application <br/>
	# **@returns** <br/>
	#  Absolute path to the application's resource
	# <hr/>
	
	fullPath: (path) ->
		path = path.replace @regex.startOrEndSlash, ''
		"#{@path}/#{path}"


	# ## date
	# 
	# 	()
	# 
	# Returns a date formatted according to config.regex.dateFormat
	# 
	# **@returns** <br/>
	#  Date string
	# <hr/>

	date: ->
		date = ( new Date() ).toString()
		match = date.match @regex.dateFormat
		match[0]


	# ## staticViewExists
	# 
	# 	(url)
	# 
	# Checks whether a static view exists for the specified URL
	# 
	# **@param url** <br/>
	#  Url to check for static view existence <br/>
	# **@returns** <br/>
	#  boolean True if static view exists, false otherwise
	# <hr/>
	
	staticViewExists: (url) ->
		url = url.replace(@regex.startOrEndSlash, '')
		if @regex.hasSlash.test(url) or @regex.tplFile.test(url)
			false
		else
			"#{url}.tpl" in @views.static


	# ## notFound
	# 
	# 	(res)
	# 
	# Renders an HTTP/404 Response. Uses the /private/views/__restricted/404.tpl template
	# 
	# **@param** <br/>
	#  res HTTP Response
	# <hr/>

	notFound: (res) ->
		@loadCookies res.__request
		@session.loadSession res.__request, res, => res.render '#404', @config.raw404

		
	# ## badRequest
	# 
	# 	(res, logData)
	# 
	# Renders an HTTP/400 Response.
	# 
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param logData** <br/>
	#  Array containing the context/msg to log (optional)
	# <hr/>

	badRequest: (res, logData) ->
		@loadCookies res.__request
		@session.loadSession res.__request, res, => res.rawHttpMessage 400, logData

	
	# ## serverError
	# 
	# 	(res, logData)
	# 
	# Renders an HTTP/500 Error. Uses the /private/views/__restricted/server-error.tpl template
	# 
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param logData** <br/>
	#  Array containing the context/msg to log (optional)
	# <hr/>

	serverError: (res, logData) ->
		@loadCookies res.__request
		@session.loadSession res.__request, res, =>
			res.render '#server-error', {}, true
			if logData?
				logData[0] = "[SERVER ERROR] - #{logData[0]}"
				@log.apply @, logData
				@emit 'server_error', logData


	# ## rawServerError
	# 
	# 	(res, message, logData)
	# 
	# Renders a raw HTTP/500 Server Error. Does not use the server-error.tpl template
	# 
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param message** <br/>
	#  Message to respond with <br/>
	# **@param logData** <br/>
	#  Array containing the context/msg to log (optional)
	# <hr/>

	rawServerError: (res, message, logData) ->
		@loadCookies res.__request
		@session.loadSession res.__request, res, => res.rawHttpMessage 500, message, logData
	
	
	# ## createClassInstance
	# 
	# 	(className)
	# 
	# Creates a class instance. Uses the application class if available in private/classes/
	# If the class does not exist, then the framework class in framework/classes is used
	# 
	# **@param className** <br/>
	#  class to instantiate <br/>
	# **@returns object** <br/>
	#  Instantiated object
	# <hr/>
	
	createClassInstance: (className) ->
		if @constructors.classes[className]?
			instance = new @constructors.classes[className] this
			instance.initialize?()
			instance
		else
			new framework.classes["C#{className}"] this

	
	# ## parseMarkdown
	# 
	# 	(string, flags)
	# 
	# Parses markdown
	# 
	# **@param string** <br/>
	#  String to parse <br/>
	# **@param string | array | int** <br/>
	#  Flags to pass to the markdown processor <br/>
	# **@returns** <br/>
	#  HTML Output for the provided markdown code
	# <hr/>
				
	parseMarkdown: (string, flags) ->
		string = @markdown.sanitizer.sanitize(string) # Strip unsafe HTML tags
		return @markdown.parse(string, flags) # Parse Markdown
	

	# ## toString
	# 
	# String representation of the application
	# <hr/>

	toString: ->
		console.log "{Application #{@domain} #{@path}}"
	

	# ## loadCookies
	# 
	# 	(req)
	# 
	# Loads cookies for the specified request
	# 
	# **@param req** <br/>
	#  HTTP Response <br/>
	# **@inner**
	# <hr/>

	loadCookies: (req) ->
		return if req.__cookies?
		req.__cookies = getRequestCookies req


	# ## purgeRedisCache
	# 
	# 	(prefixes...)
	# 
	# Deletes all cache entries on the Redis CacheStore for a specific cache prefix
	# 
	# **@param prefixes** <br/>
	#  Key Prefixes <br/>
	# **@inner**
	# <hr/>
	
	purgeRedisCache: (prefixes...) ->
		@debug "Purging redis cache for #{prefixes.toString()}"
		for prefix in prefixes
			prefix += '_*'
			redis = @redisClients['cacheStore']
		
			# Response cache should be cleaned up upon server startup. New caches will be created upon access.
			redis.keys prefix, (err, data) =>
				if err then console.exit err
				else if data.length > 0
					data[i] = ['del', val] for val,i in data
					multi = redis.multi(data).exec (err, replies) => if err then console.exit err
				else
					null  # Nothing to purge
				null
		null

	# <!-- ============================================================================================ -->
	# # Private Functions <hr/><br/>
	# <!-- ============================================================================================ -->


	# ## getStaticDirs
	# 
	# 	()
	# 
	# Gets a list of directories in docroot (blocking operation)
	# 
	# **@returns array** <br/>
	#  List of directories <br/>
	# **@inner**
	# <hr/>
	
	getStaticDirs = ->
		dirs = []
		fs = @modules.fs
		files = fs.readdirSync "#{@path}/docroot"
		for file in files
			stat = fs.lstatSync ("#{@path}/docroot/#{file}")
			dirs.push file if stat.isDirectory()
		dirs
	

	# ## parseUrl
	# 
	# 	(url)
	# 
	# Parses a url into its different components
	# 
	# **@param url** <br/>
	#  Url to parse <br/>
	# **@returns object** <br/>
	#  Url components
	# <hr/>
	
	parseUrl = (url) ->
		framework.modules.url.parse url
	
	
	# ## getRequestCookies
	# 
	# 	(req)
	# 
	# Gets the cookies for the request
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@inner**
	# <hr/>
	
	getRequestCookies = (req) ->
		if req.headers.cookie?
			try
				parseCookie(req.headers.cookie)
			catch e
				@log req.__urlData.pathname, "Error parsing cookie header: #{e.toString()}"
				{}
		else {}
	
	
	# ## parseCookie
	# 
	# 	(str)
	# 
	# Parse cookie header
	# 
	# **@param str** <br/>
	#  Cookie header <br/>
	# **@returns object** <br/>
	#  Cookie jar with key/value pairs <br/>
	# **@inner**
	# <hr/>
	
	parseCookie = (str) ->
		obj = {}
		pairs = str.split(/[;,] */)

		for pair in pairs
			eqlIndex = pair.indexOf '='
			key = pair.substr(0, eqlIndex).trim().toLowerCase()
			val = pair.substr(++eqlIndex, pair.length).trim()
			val = val.slice(1, -1)  if '"' is val[0]
			
			if obj[key] is undefined
				val = val.replace(/\+/g, ' ')
				try
					obj[key] = decodeURIComponent val
				catch err
					if err instanceof URIError
						obj[key] = val
					else
						throw err

		obj
	
	
	# ## buildPartialViews
	# 
	# 	()
	# 
	# Builds the partial views cache into app.partialViews
	# 
	# **@inner**
	# <hr/>
	
	buildPartialViews = ->
		skip = ['header.tpl', 'footer.tpl']
		framework.modules.file.walkSync "#{@path}/private/views", (dirPath, dirs, files) =>
			for file in files
				
				if @regex.partialView.test(file) or ( dirPath.indexOf('__layout') > 0 and @regex.tplFile.test(file) and file not in skip )
					path = "#{dirPath}/#{file}"
				else
					continue
					
				relPath = @relPath path, 'private/views'
				buffer = framework.modules.fs.readFileSync path, 'utf-8'
				anonFunction = @template.renderPartial buffer, relPath
				
				if typeof anonFunction is 'function'
					@partialViews[relPath] = anonFunction # callback
				else
					throw anonFunction # exception
					
			null
			
		null

	
	# ## instantiateExtraClasses
	# 
	# 	()
	# 
	# Instantiate additional classes present in private/classes (not part of the standard framework classes)
	# 
	# **@inner**
	# <hr/>

	instantiateExtraClasses = ->
		classes = framework.util.ls @fullPath('/private/classes'), @regex.jsFile
		initialized = []
		for file in classes
			className = file.replace @regex.jsFile, ''
			# Since @regex.jsFile returns true for both .js and .coffee files,
			# an extra check needs to be performed to prevent the same class being instantiated twice
			continue if className in initialized
			unless "C#{className}" of framework.classes
				initialized.push className
				ob = new @constructors.classes[className] this
				ob.app = this # Add app instance to @app property (manual constructor)
				ob.initialize?() # Run initialize function, if available
				if ob.alias
					if @[ob.alias] is undefined then @[ob.alias] = ob
					else console.log "[#{@.domain}] - Unable to set #{className} on @#{ob.alias}: Key exists."; process.exit()
				else
					@[className] = ob
		null

module.exports = CApplication;

# <br/>