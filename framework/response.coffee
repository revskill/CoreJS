
# # OutgoingMessage
#
# Extends http.OutgoingMessage
#
# <hr/><br/>

{OutgoingMessage} = framework.modules.http

# ## render
# 
# 	(view, data, raw)
# 
# Renders a specified view
# 
# **@param view** <br/>
#  View to render <br/>
# **@param object** <br/>
#  data Local variables to use within view <br/>
# **@param boolean** <br/>
#  raw Will render the view without header/footer if true
# <hr/>

OutgoingMessage::render = (view, data, raw) ->
	
	if @cacheID?
		redis = @__app.redisClients['cacheStore']
		redis.get "response_cache_#{@cacheID}", (err, response) =>
			if err then @__app.serverError this, [err]
			else unless response?
				# Data not found, render
				@__doResponseCache = true
				asyncRender.call this, view, data, raw
			else
				# Got data, respond with cache
				# Object to satisfy condition:  `runtimeData.viewCounter is runtimeData.views.length`
				@__runtimeData =
					viewCounter: 0
					views: []
					buffer: response
				@__app.debug "Using cached response for #{@cacheID}"
				renderViewBuffer.call this
	else
		asyncRender.call this, view, data, raw
				
# ## getViewPath
# 
# 	(view)
# 
# Retrieves the view path
# 	
# **VIEW RENDERING LOGIC**
# 
# #### Using a view alias or filename
# 
# 	res.render('index'); -> will render 'main/main-index.tpl'
# 	res.render('hello-there.tpl) -> will render 'main/hello-there.tpl'
# 
# #### Using a path relative to the views/ directory
# 
# 	res.render('main/index') -> will render 'main/main-index.tpl'
# 	res.render('/main/index') -> will render 'main/main-index.tpl'
# 	res.render('main/index.tpl) -> will render 'main/index.tpl'
# 	res.render('/hello') -> will render /hello.tpl (relative to /views)
# 	res.render('/hello.tpl') -> will render /hello.tpl (relative to /views)
# 
# **@param view** <br/>
#  View to retrieve the path of <br/>
# **@returns** <br/>
#  View Path
# <hr/>

OutgoingMessage::getViewPath = (view) ->
	
	app = @__app
	controller = (if typeof @__controller is 'object' then @__controller else app.controllers.MainController)
	dirname = app.modules.path.dirname(view)
	alias = path = file = depth = undefined
	
	if app.regex.layoutView.test(view)
		view = view.replace app.regex.layoutView, ''
		view += '.tpl'	unless app.regex.tplFile.test(view)
		path = "#{app.path}/private/views/__layout/#{view}"
		
	else if app.regex.restrictedView.test(view)
		view = view.replace app.regex.restrictedView, ''
		view += '.tpl'	unless app.regex.tplFile.test(view)
		path = "#{app.path}/private/views/__restricted/#{view}"
		
	else if not app.regex.startsWithSlash.test(view) and dirname is '.'
		alias = controller.getAlias()
		if app.regex.tplFile.test(view)
			path = "#{app.path}/private/views/#{alias}/#{view}"
		else
			path = "#{app.path}/private/views/#{alias}/#{alias}-#{view}.tpl"
			
	else
		view = view.replace app.regex.startsWithSlash, ''
		dirname = app.modules.path.dirname(view)
		if dirname is '.'
			path = "#{app.path}/private/views/#{view}"
			path += '.tpl'	unless app.regex.tplFile.test(view)
		else
			depth = ( app.template.searchPattern(view, '/') )['/'].length
			if depth is 1
				view = view.split('/')
				path = ( if app.regex.tplFile.test(view[1]) then "#{app.path}/private/views/#{view[0]}/#{view[1]}" else "#{app.path}/private/views/#{view[0]}/#{view[0]}-#{view[1]}.tpl" )
			else
				path = "#{app.path}/private/views/#{view}"
				path += '.tpl'	unless app.regex.tplFile.test(view)
				
	path

# ## useCache
# 
# 	(cacheID)
# 
# Caches the response buffer returned by OutgoingMessage::render
# 
# Uses Redis as the backend. The cacheStore database is used.
# 
# **@param cacheID** <br/>
#  cacheID to use for cacheStore <br/>
# <hr/>

OutgoingMessage::useCache = (cacheID) ->
	@cacheID = cacheID if @__app.responseCaching is on

# ## rawHttpMessage
# 
# 	(statusCode, message, logData)
# 
# Renders a Raw HTTP Message (usually one liners).
# 
# If it's an AJAX request, the response will be raw. Otherwise, the private/views/__restricted/notification.tpl template will be used
# 
# **@param statusCode** <br/>
#  HTTP Status code according to [RFC 2616](http://www.w3.org/Protocols/rfc2616/rfc2616.html) <br/>
# **@param message** <br/>
#  Message to respond with <br/>
# **@param array** <br/>
#  logData Data to log (optional)
# <hr/>

OutgoingMessage::rawHttpMessage = (statusCode, message, logData) ->
	
	if typeof statusCode is 'object'
		{statusCode, message, raw, logData} = statusCode
		@statusCode = statusCode if statusCode?
	else
		if logData is undefined and message is undefined and typeof statusCode is 'string'
			message = statusCode
			statusCode = 200
		
		if logData is undefined and framework.modules.util.isArray(message)
			logData = message
			message = undefined
		
		@statusCode = statusCode
	
	if logData? and @statusCode is 500
		logData[0] = "[SERVER ERROR] #{logData[0]}"
		
	else if logData? and @statusCode is 404
		logData[0] = "[NOT FOUND] #{logData[0]}" 
		
	else if logData?
		logData[0] = "[BAD REQUEST] #{logData[0]}"	if logData? and @statusCode is 400
	
	buffer = ( if message? then message else "#{@statusCode} #{framework.modules.http.STATUS_CODES[@statusCode]}\n" )
	
	if raw or @__request.__isAjax is on
		@setHeaders
			'Cache-Control': 'no-cache'
			'Content-Type': 'text/plain'
		@sendHeaders()
		@end buffer, @__app.config.encoding
	else
		# Only parse markdown if not rendering text/plain
		buffer = @__app.parseMarkdown(buffer, 'internal')
		@render '#notification', {message: buffer}, @__app.config.rawNotifications
		
	@__app.log.apply @__app, logData if logData?
	
	null
	

# ## redirect
# 
# 	(location)
# 
# Redirects to a specified location
# 
# **@param location** <br/>
#  URL to redirect to
# <hr/>

OutgoingMessage::redirect = (location) ->
	request = @__request
	if request.sessionChanged?()
		request.saveSessionState( => redirect.call @, location )
	else
		redirect.call @, location
	null


# ## setCookie
# 
# 	(name, val, opts)
# 
# Sets an HTTP/HTTPS Cookie.
#
# [Cookie Reference](http://curl.haxx.se/rfc/cookie_spec.html)
# 
# **@param name** Cookie to set <br/>
# **@param val** Value to set <br/>
# **@param object** opts Options to create the cookie
# <hr/>

OutgoingMessage::setCookie = (name, val, opts) ->
	opts ?= {}
	pairs = [ "#{name}=#{encodeURIComponent(val)}" ]
	
	removeCookie = (framework.util.isTypeOf(opts.expires, 'number') and opts.expires < 0)
	opts.domain = @__app.domain unless opts.domain?
	opts.domain = null if opts.domain is 'localhost' # Cookies must have a dot in their name, otherwise path is omitted
	opts.path = '/'	unless opts.path?
	opts.expires = ( if framework.util.isTypeOf(opts.expires, 'number') then new Date(Date.now() + opts.expires * 1000) else undefined )
	pairs.push "domain=#{opts.domain}" if opts.domain?
	pairs.push "path=#{opts.path}"
	pairs.push "expires=#{opts.expires.toUTCString()}" if opts.expires?
	pairs.push 'httpOnly' if opts.httpOnly is undefined or opts.httpOnly?
	pairs.push 'secure'	if opts.secure?
	
	@__request.__cookies[name.toLowerCase()] = val unless removeCookie
	@__setCookie.push pairs.join('; ')


# ## removeCookie
# 
# 	(name)
# 
# Removes a cookie
# 
# **@param cookie** <br/>
#  Cookie to remove
# <hr/>

OutgoingMessage::removeCookie = (name) ->
	@__app.loadCookies @__request unless @__request.__cookies?
	@setCookie name, null, {expires: -3600}
	delete @__request.__cookies[name.toLowerCase()]
	null


# ## removeCookies
# 
# Removes several cookies
# 
# **@param array** <br/>
#  Array of cookie names to remove
# <hr/>

OutgoingMessage::removeCookies = (names) ->
	@removeCookie names[key] for key of names


# ## hasCookie
# 
# 	(cookie)
# 
# Checks if cookie exists
# 
# **@param cookie** <br/>
#  Cookie name to check <br/>
# **@returns boolean** <br/>
#  True if cookie exists
# <hr/>

OutgoingMessage::hasCookie = (cookie) ->
	@__request.hasCookie cookie


# ## getCookie
# 
# 	(cookie)
# 
# Retrieves a cookie value
# 
# **@param cookie** <br/>
#  Cookie to retrieve <br/>
# **@returns** <br/>
#  Cookie value
# <hr/>

OutgoingMessage::getCookie = (cookie) ->
	@__request.getCookie cookie


# ## setHeaders
# 
# 	(headers)
# 
# Sets headers to be used when the HTTP Response is sent
# 
# **@param object** <br/>
#  headers HTTP Headers to set
# <hr/>

OutgoingMessage::setHeaders = (headers) ->
	return if @_header?
	@__headers = _.extend @__headers, headers


# ## headerFilter
# 
# 	()
# 
# Header filter processing. Enables the use of callbacks in config.headers
# <hr/>

OutgoingMessage::headerFilter = ->
	return if @_header?
	for field, action of @__headers
		if typeof action is 'string'
			@__headers[field] = action
		else if typeof action is 'function'
			@__headers[field] = action.call @__app, @__request, this
		else
			continue
	null


# ## sendHeaders
#
# 	()
# 
# Sends the HTTP Response headers
# <hr/>

OutgoingMessage::sendHeaders = ->
	return if @_header?
	@headerFilter()
	@setHeader 'Set-Cookie', @__setCookie if @__setCookie.length
	@setHeader key, @__headers[key] for key of @__headers
	@writeHead @statusCode


# <!-- ============================================================================================ -->
# # Private Functions <hr/><br/>
# <!-- ============================================================================================ -->

# ## asyncRender
# 
# 	(view, data, raw)
# 
# Local function to be used with OutgoingMessage::render. This code needs to be run on different places
# in different times.
# 
# Receives the same parameters of OutgoingMessageessage::render
# <hr/>

asyncRender = (view, data, raw) ->
	if typeof data is 'boolean' and raw is undefined
		raw = data
		data = undefined
	app = @__app
	controller = (if typeof @__controller is 'object' then @__controller else app.controller)

	viewInstance = new app.constructors.classes.View app, app.controller.getAlias(controller.constructor.name)

	data ?= {}
	data = _.extend(data,
		__viewInstance: viewInstance
		app: app
		res: this
		req: @__request
		session: @__request.__session
		cookies: @__request.__cookies
	)

	views = (if raw then [ view ] else [ '@header', view, '@footer' ])

	if view is '#404'
		@statusCode = 404
	else 
		@statusCode = 500 if view is '#server-error'

	@__runtimeData =
		buffer: ''
		data: data
		views: views
		viewCounter: 0
		currentView: null
		controller: controller

	renderViewBuffer.call this

	null

# ## renderViewBuffer
# 
# 	()
# 
# Renders a specific view template. Part of the OutgoingMessage::render loop
# 
# **@params string** <br/>
#  Rendered view <br/>
# **@inner**
# <hr/>

renderViewBuffer = ->
	runtimeData = @__runtimeData
	app = @__app

	if runtimeData.viewCounter is runtimeData.views.length
		
		# Reusable code block created within scope
		codeBlock = ->
			unless @__headers['Cache-Control']?
				@setHeaders 'Cache-Control': app.config.cacheControl[ (if @statusCode in [400,500] then 'error' else 'dynamic') ]
			request = @__request
			if not request.__isStatic and request.sessionChanged?()
				request.saveSessionState =>
					@sendHeaders()
					@end runtimeData.buffer, app.config.encoding
			else
				@sendHeaders()
				@end runtimeData.buffer, app.config.encoding
	
		if @__doResponseCache is true
			# Cache response buffer if @cacheID provided, then Render view
			redis = @__app.redisClients['cacheStore']
			redis.set "response_cache_#{@cacheID}", runtimeData.buffer, (err, info) =>
				if err then @__app.serverError this, [err]
				else 
					@__app.debug "Cached response for #{@cacheID}"
					codeBlock.call this
		else
			# Render view normally (handles both cached and non-cached)
			codeBlock.call this
		
		return

	viewCaching = app.viewCaching
	viewCallbacks = app.views.callbacks
	viewBuffers = app.views.buffers
	data = runtimeData.data
	controller = runtimeData.controller
	view = runtimeData.views[runtimeData.viewCounter]
	template = @getViewPath(view)
	relPath = app.relPath(template, 'private/views')
	buffer = logData = undefined
	
	if viewCaching
		if framework.util.isTypeOf(viewCallbacks[relPath], 'function')
			try
				buffer = viewCallbacks[relPath].call controller, data
			catch e
				buffer = e
				
			if typeof buffer is 'string'
				app.emit 'view_cache_access', app, relPath
				runtimeData.buffer += buffer
				runtimeData.viewCounter++
				renderViewBuffer.call this
				return
				
			else
				app.emit 'view_cache_access', app, relPath
				logData = [ relPath, buffer ]
				app.serverError this, logData
				return
				
		else if viewBuffers[relPath]? and framework.modules.util.isArray(viewBuffers[relPath])
			app.emit 'view_cache_access', app, relPath
			logData = viewBuffers[relPath]
			app.serverError this, logData
			return
	
	app.modules.path.exists template, (exists) =>
		app.emit 'view_cache_store', app, relPath if viewCaching
		
		if exists
			app.modules.fs.readFile template, 'utf-8', (err, templateBuffer) =>
				if err
					logData = viewBuffers[relPath] = [ relPath, 'Unable to read file' ]
					viewBuffers[relPath] = logData if viewCaching
					app.serverError @, logData
				else
					buffer = app.template.render templateBuffer, data, controller, relPath
					if typeof buffer is 'string'
						runtimeData.buffer += buffer
						runtimeData.viewCounter++
						renderViewBuffer.call @
					else
						logData = [ relPath, buffer ]
						viewBuffers[relPath] = logData if viewCaching
						app.serverError @, logData
						
		else
			logData = viewBuffers[relPath] = [ relPath, "The file can't be found" ]
			viewBuffers[relPath] = logData if viewCaching
			app.serverError @, logData
			
	null

# ## redirect
# 
# 	(location)
# 
# Internal redirect function. Used by OutgoingMessage::redirect
# 
# **@param location** <br/>
#  Location to redirect to <br/>
# **@inner**
# <hr/>

redirect = (location) ->
	return if @_header?
	@statusCode = 302
	@__headers = _.extend {Location: location}, @__app.config.headers
	@setHeader 'Set-Cookie', @__setCookie if @__setCookie.length > 0
	@headerFilter()
	@writeHead @statusCode, @__headers
	@end()
	
# <br/>