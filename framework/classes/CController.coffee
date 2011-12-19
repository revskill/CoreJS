
# # CController
# 
# Base class used to extend Application Controllers
#
# <hr/><br/>

class CController
	
	aliasRegex = { re1: /Controller$/, re2: /^-/ }
	
	queuedRoutes: {}
	authRequired: false
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>	
	
	constructor: (app) ->
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
		registerRoute.apply this, args for args in @queuedRoutes[@app.domain] # Register routes on initialization
	
	# <!-- ============================================================================================ -->
	# # Routing Functions (static) <hr/><br/>
	# <!-- ============================================================================================ -->
	
	# ## route
	# ## routeGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 	
	# Adds a generic route, matching only GET requests
	# 
	# The route will be public or private, depending on the value of **@authRequired**
	# 
	# **@param route** <br/>
	#  Route to add <br/>
	# **@param object arg2** <br/>
	#  Route Validation (optional) <br/>
	# **@param object arg3** <br/>
	#  Route Validation error messages. Arranged in key:msg pairs (optional) <br/>
	# **@param function arg4** <br/>
	#  Callback to render when the route is resolved <br/>
	# **@static**
	# <hr/>
	
	@route = @routeGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getMethod, @::authRequired, route ], arg2, arg3, arg4

	
	# ## routePost
	# 
	# Adds a generic route, matching only POST requests
	#
	# The route will be *public or private*, depending on the *@authRequired* option of the controller
	# <hr/>

	@routePost = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.postMethod, @::authRequired, route ], arg2, arg3, arg4


	# ## routeGetPost
	# ## routePostGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a generic route matching both GET and POST requests
	# 
	# The route will be *public or private*, depending on the *@authRequired* option of the controller
	# <hr/>

	@routeGetPost = @routePostGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getPostMethod, @::authRequired, route ], arg2, arg3, arg4

	
	# ## publicRoute
	# ## publicRouteGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *public* route, matching only GET requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@publicRoute = @publicRouteGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getMethod, false, route ], arg2, arg3, arg4

		
	# ## publicRoutePost
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *public* route, matching only POST requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@publicRoutePost = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.postMethod, false, route ], arg2, arg3, arg4


	# ## publicRouteGetPost
	# ## publicRoutePostGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *public* route, matching both GET and POST requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@publicRouteGetPost = @publicRoutePostGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getPostMethod, false, route ], arg2, arg3, arg4


	# ## privateRoute
	# ## privateRouteGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *private* route, matching only GET requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@privateRoute = @privateRouteGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getMethod, true, route ], arg2, arg3, arg4


	# ## privateRoutePost
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *private* route, matching only POST requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@privateRoutePost = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.postMethod, true, route ], arg2, arg3, arg4

	
	# ## privateRouteGetPost
	# ## privateRoutePostGet
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Adds a *private* route, matching both GET and POST requests
	# 
	# This route will ignore the *authRequired* option of the controller
	# <hr/>

	@privateRouteGetPost = @privateRoutePostGet = (route, arg2, arg3, arg4) ->
		registerRoute [ this, framework.regex.getPostMethod, true, route ], arg2, arg3, arg4

	
	# ## get
	# 
	# 	(req, token, callback)  [fields]
	# 
	# Handles HTTP GET Query Data.
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param token** <br/>
	#  CSRF Token to validate against (optional) <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>

	get: (req, token, callback) ->
		res = req.__response
		if callback is undefined
			callback = token
			token = undefined
		fields = req.__queryData
		if req.method is 'GET'
			if token
				if fields["#{token}_key"]?
					csrf_check_passed = @app.csrf.checkToken(req, token, fields["#{token}_key"])
					if csrf_check_passed
						if @app.validate(req, fields, true)
							delete req.__params[key] for key of fields when req.__params[key] is undefined
							callback.call this, fields
						else if req.__route.messages?
							[field, badVal] = req.__invalidParam
							if (msg = req.__route.messages[field])?
								res.rawHttpMessage 400, "#{msg}"
							else
								@app.notFound res
						else
							@app.notFound res
					else
						res.rawHttpMessage 400
				else
					res.rawHttpMessage 400
			else if @app.validate(req, fields, true)
				delete req.__params[key] for key of fields when req.__params[key] is undefined
				callback.call this, fields
			else if req.__route.messages? and req.__invalidParam?
				[field, badVal] = req.__invalidParam
				if (msg = req.__route.messages[field])?
					res.rawHttpMessage 400, "#{msg}"
				else
					@app.notFound res
			else
				@app.notFound res
		else if req.method is 'POST'
			res.rawHttpMessage 400
		else
			@app.notFound res


	# ## post
	# 
	# 	(req, token, callback)  [fields, files]
	# 
	# Handles HTTP POST Data, including Fields and Files
	# 
	# **@param** <br/>
	#  req HTTP Request <br/>
	# **@param token** <br/>
	#  CSRF Token to validate against (optional) <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>

	post: (req, token, callback) ->
		res = req.__response
		if callback is undefined
			callback = token
			token = null
		if req.method is 'POST'
			self = this
			postData = req.__postData
			fields = postData.fields
			files = postData.files
			if token
				if fields["#{token}_key"]?
					csrf_check_passed = @app.csrf.checkToken req, token, fields["#{token}_key"]
					if csrf_check_passed
						callback.call self, fields, files if @app.validate(req, fields) # @app.validate sends a rawHttpMessage
					else
						@cleanupFilesUploaded files, true
						res.rawHttpMessage 400
				else
					@cleanupFilesUploaded files, true
					res.rawHttpMessage 400
			else
				callback.call self, fields, files if @app.validate(req, fields) # @app.validate sends a rawHttpMessage
		else
			@cleanupFilesUploaded files, true
			res.rawHttpMessage 400

	
	# ## getControllerByAlias
	# 
	# 	(name)
	# 
	# Retrieves a controller instance by its alias
	# 
	# **@param name** <br/>
	#  Alias (dashed representation) of the controller <br/>
	# **@returns** <br/>
	#  Classname of the controller
	# <hr/>

	getControllerByAlias: (name) ->
		name = name.replace(@app.regex.startOrEndSlash, '')
		controllerName = framework.util.toCamelCase("#{name}-controller")
		controller = @app.controllers[controllerName]
		if controller is undefined then null else controller


	# ## getAlias
	# 
	# 	(controllerClass)
	# 
	# Gets the alias (dashed representation) of a controller's class
	# 
	# **@param controllerClass** <br/>
	#  Classname of the controller <br/>
	# **@returns** <br/>
	#  Alias of the controller
	# <hr/>

	getAlias: (controllerClass) ->
		controllerClass = @constructor.name unless controllerClass
		_s.dasherize(controllerClass.replace(aliasRegex.re1, '')).replace aliasRegex.re2, ''


	# ## processRoute
	# 
	# 	(urlData, req, res)
	# 
	# Process a controller's route. Determines which route function to render.
	# 
	# **@param object urlData** <br/>
	#  Object containing the url components <br/>
	# **@param req** <br/>
	#  HTTP Request
	# **@param res** <br/>
	#  HTTP Response
	# <hr/>

	processRoute: (urlData, req, res) ->
		res.__controller = this
		key = route = regex = match = controller = alias = undefined
		self = this
		routes = @app.routes[@constructor.name] or []
		url = urlData.pathname

		for key of routes
			route = routes[key]
			
			if route.path is url and _.isEmpty(route.validation)

				if route.method.test(req.method)
					req.__route = route
					if req.method is 'POST'
						
						if req.exceededUploadLimit() then return
						
						req.getPostData (fields, files) =>
							req.__isAjax = true if fields.ajax? and parseInt(fields.ajax) is 1
							delete fields.ajax
							files = @cleanupFilesUploaded files
							req.__postData = { fields: fields, files: files }
							@app.session.loadSession req, res, ->
								if route.authRequired
									if req.__session.user?
										route.callback.call self, req, res
									else
										@app.controller.cleanupFilesUploaded files, true
										@app.login res
								else
									route.callback.call self, req, res
									
					else if req.method is "GET"
						@app.session.loadSession req, res, =>
							if route.authRequired
								if req.__session.user?
									route.callback.call self, req, res
								else
									@app.login res
							else
								route.callback.call self, req, res
					
				else
					
					@app.notFound res
					
				return
				
			else if route.regex.test(urlData.pathname)
			
				if route.method.test(req.method)
					req.__route = route
					
					if route.validation?
					
						match = urlData.pathname.match(route.regex)

						# Add route params
						i = 1
						for key of route.validation
							req.__params[key] = match[i]
							i++
							
					if req.method is 'POST'
						
						if req.exceededUploadLimit() then return
						
						req.getPostData (fields, files) =>
							req.__isAjax = true	if fields.ajax? and parseInt(fields.ajax) is 1
							delete fields.ajax
							files = @cleanupFilesUploaded files
							req.__postData = { fields: fields, files: files }
							@app.session.loadSession req, res, ->
								if route.authRequired
									if req.__session.user?
										route.callback.call self, req, res 
									else
										@app.controller.cleanupFilesUploaded files, true
										@app.login res
								else
									route.callback.call self, req, res
									
					else if req.method is 'GET'
						@app.session.loadSession req, res, =>
							if route.authRequired
								if req.__session.user?
									route.callback.call self, req, res
								else
									@app.login res
							else
								route.callback.call self, req, res
				else
					@app.notFound res

				return
				
		# ### Route Processing Order
		# 
		# 1. '/' and Single Parameter routes  <br/>
		# 	a) If a controller is found associated with the route (and a route in it matches), render it <br/>
		# 	b) If a route is found in MainController that matches, render it <br/>
		# 	c) If there's a static view that matches the route, render it <br/>
		# 	d) Render 404
		# 
		# 2. Multiple Parameter routes (processed with CRouter) <br/>
		# 	a) If a controller is found associated with the route (and a route in it matches), render it <br/>
		# 	b) If a route is found in MainController that matches, render it <br/>
		# 	c) Render 404
		
		if @constructor.name is 'MainController'
			if req.__isMainRequest  # If it's a singleParam request, process it normally
				alias = url.replace(@app.regex.startOrEndSlash, '')
				controller = if alias isnt 'main' then @getControllerByAlias(alias) else null
				if controller? and @app.routes[@constructor.name]?
					controller.processRoute.call controller, urlData, req, res
				else if @app.staticViewExists(url)
					# Render static view
					renderStaticView.call this, url, req, res
				else
					# If there's no controller, and there's no static view to render. Try loading static resource, render 404 if not available
					@app.serveStatic "#{@app.path}/docroot#{url}/", req, res
			
			else if @app.staticViewExists(url)
				# Render static view
				renderStaticView.call this, url, req, res
				
			else
				# If there's no controller, and there's no static view to render. Try loading static resource, render 404 if not available
				@app.serveStatic "#{@app.path}/docroot#{url}/", req, res
		
		else if @app.staticViewExists(url)
		
			# Render static view
			renderStaticView.call this, url, req, res
			
		else
		
			if req.__isMainRequest
				# Try loading static resource, render 404 if not available
				@app.serveStatic "#{@app.path}/docroot#{url}/", req, res
			else
				#  If it's a Main Request (e.g. /test), then go through main
				@app.controller.processRoute.call @app.controller, urlData, req, res
			
		null
			
	# ## exec
	# 
	# 	(urlData, req, res)
	# 
	# Execute a given route
	# 
	# **@param object urlData** <br/>
	#  Object containing the url components <br/>
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response
	# <hr/>

	exec: (urlData, req, res) ->
		url = urlData.pathname
		matches = url.match(@app.regex.controllerAlias)
		controller = (if matches then @app.controller.getControllerByAlias(matches[1]) or @app.controllers.MainController else @app.controllers.MainController)
		if controller?
			controller.processRoute.call controller, urlData, req, res
		else
			@app.notFound res
		null


	# ## cleanupFilesUploaded
	# 
	# 	(files, removeAll)
	# 
	# Cleanup uploaded files that have a file size of 0
	# 
	# If specified, will remove all the files, regardless of their size
	# 
	# **@param array files** <br/>
	#  Array of file objects, containing fileData instances provided by the formidable module <br/>
	# **@param removeAll** <br/>
	#  Will remove all the files, regardless of their size <br/>
	# **@returns** <br/>
	#  object Array containing file objects (after the clean operation)
	# <hr/>

	cleanupFilesUploaded: (files, removeAll=false) ->
		filtered = {}
		if removeAll
			@app.modules.fs.unlink fileData.path for filename, fileData of files
		else
			(if fileData.size is 0 then @app.modules.fs.unlink fileData.path else filtered[filename] = fileData) for filename, fileData of files
		filtered
	

	# <!-- ============================================================================================ -->
	# # Private Functions <hr/><br/>
	# <!-- ============================================================================================ -->
	
	
	# ## registerRoute
	# 
	# 	(route, arg2, arg3, arg4)
	# 
	# Registers a route
	# 
	# ### Route Definition Parameters
	# 
	# 	a) this.route(route, callback)  <br/>
	# 	b) this.route(route, validation, callback) --> GET & POST (w/o messages) Requests  <br/>
	# 	c) this.route(route, validation, messages, callback) --> POST Requests with messages <br/>
	# 
	# **@param route** <br/>
	#  Route to add <br/>
	# **@param object arg2** <br/>
	#  Route Validation (optional) <br/>
	# **@param object arg3** <br/>
	#  Route Validation error messages. Arranged in key:msg pairs (optional) <br/>
	# **@param function arg4** <br/>
	#  Callback to render when the route is resolved <br/>
	# **@inner**
	# <hr/>
	
	registerRoute = (route, arg2, arg3, arg4) ->
		
		# Route registration happens in 2 iterations:
		#
		# 1. The routes are added in the Application's controller (routes are queued) <br/>
		# 2. On instantiation, the routes are registered
		
		unless @app?
			CController::queuedRoutes[framework.currentDomain].push [route, arg2, arg3, arg4]
			return
			
		controller = route[0]
		caller = controller.name
		method = route[1]
		authRequired = route[2]
		route = route[3]
		
		if arg3 is undefined and typeof arg2 is 'function'
			[validation, messages, callback] = [null, null, arg2]
		else if arg4 is undefined and typeof arg2 is 'object' and typeof arg3 is 'function'
			[messages, validation, callback] = [null, arg2, arg3]
		else if typeof arg2 is 'object' and typeof arg3 is 'object' and typeof arg4 is 'function'
			[validation, messages, callback] = [arg2, arg3, arg4]
		else
			throw new error "[#{@app.domain}] Unable to process route on #{caller}: #{route}"
			return
			
		route = "/#{route}" unless @app.regex.startsWithSlash.test route
		
		route = "/#{controller::getAlias(caller)}#{route}" if caller isnt 'MainController'
		@app.routes[caller] = [] unless @app.routes[caller]?
		route = route.replace @app.regex.endsWithSlash, '' if route isnt '/'

		try
			unless validation? 
				regex = new RegExp('^'+route.replace(@app.regex.regExpChars, '\\$1') + '\\/?$') # allow an optional slash at the end
			else
				regex = route.replace(@app.regex.regExpChars, '\\$1')
				for key of validation
					validation[key] = @app.regex[validation[key]] if _.isString(validation[key]) and validation[key] in @app.regexKeys
					regex = regex.replace(new RegExp(':' + key, 'g'), '(' + validation[key].toString().replace(@app.regex.startOrEndSlash,'').replace(@app.regex.startOrEndRegex,'') + ')' )
				regex = new RegExp('^'+regex+'\\/?$'); # allow an optional slash at the end
		catch e
			throw new error "[#{@app.domain}] Unable to process route on #{caller}: #{route}"
			return
			
		paramKeys = ( key for key of validation )

		@app.routes[caller].push
			path: route
			method: method
			regex: regex
			validation: validation or {}
			paramKeys: paramKeys
			messages: messages
			authRequired: authRequired
			callback: callback
			caller: caller
			

	# ## renderStaticView
	# 
	# 	(url, req, res)
	# 	
	# Helper function to render static views. Used multiple times within CController
	# 
	# **@param url** <br/>
	#  Url to render <br/>
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@inner**
	# <hr/>

	renderStaticView = (url, req, res) ->
		
		url = url.replace @app.regex.endsWithSlash, ''
		
		# For static templates, an event is emitted with its url as alias
		@app.emit 'static_view', req, res, url
		return if req.__stopRoute is true # Ability to stop request on the 'static_view' event
		@app.session.loadSession req, res, -> res.render "#{url}.tpl"


module.exports = CController

# <br/>