
# # IncomingMessage
#
# Extends http.IncomingMessage
#
# **@uses**
#
# - [formidable](https://github.com/felixge/node-formidable)
#
# <hr/><br/>

{IncomingMessage} = framework.modules.http

IncomingMessage::__saveSession = null
IncomingMessage::__sessionQueue = {}

# ## hasCookie
# 
# 	(cookie)
# 
# Checks if cookie exists
# 
# **@param cookie** <br/>
# Cookie name to check <br/>
# **@returns boolean**  <br/>
# True if cookie exists
# <hr/>

IncomingMessage::hasCookie = (cookie) ->
	@__app.loadCookies this unless @__cookies?
	@__cookies[cookie.toLowerCase()]?


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

IncomingMessage::getCookie = (cookie) ->
	@__app.loadCookies this unless @__cookies?
	@__cookies[cookie.toLowerCase()]


# ## removeCookie
# 
# 	(cookie)
# 
# Removes a cookie
# 
# **@param** <br/>
#  cookie Cookie to remove
# <hr/>

IncomingMessage::removeCookie = (cookie) ->
	@__response.removeCookie cookie


# ## removeCookies
# 
# 	(cookies)
# 
# Removes several cookies
# 
# **@param array** <br/>
#  Array of cookie names to remove
# <hr/>

IncomingMessage::removeCookies = (cookies) ->
	@__response.removeCookies cookies


# ## saveSessionState
# 
# 	(callback)  [ ]
# 
# Saves the current session state
# 
# **@param callback** <br/>
#  Callback to call after the session has been saved
# <hr/>

IncomingMessage::saveSessionState = (callback) ->
	
	self = this
	app = @__app
	session = @__session
	multi = app.redisClients.sessionStore.multi()
	sessId = @getCookie app.session.sessCookie
	
	expires = if session.user? then (if session.pers then app.config.session.permanentExpires else app.config.session.temporaryExpires) else app.config.session.guestExpires

	multi.hmset sessId, session

	for key of @__origSessionState
		multi.hdel sessId, key unless session[key]?
	
	multi.expire sessId, expires
	multi.exec (err, replies) ->
		if err or replies[0] isnt 'OK'
			app.serverError self.__response, [ 'REDIS SERVER', err ]
		else
			callback.call app

	null


# ## sessionChanged
# 
# 	()
# 
# Check if the session has changed
# 
# **@param bool** <br/>
#  True if the session has changed
# <hr/>

IncomingMessage::sessionChanged = ->
	curSessionJson = JSON.stringify @__session
	@hasCookie(@__app.session.sessCookie) and curSessionJson isnt @__sessionJson and curSessionJson isnt '{}'


# ## getPostData
# 
# 	(callback)   [fields, files]
# 
# Retrieves HTTP POST data, this includes Fields and Files.
# 
# **@uses** <br/>
#
# 	app.config.server.maxFieldSize
# 	app.config.server.maxUploadSize
# 	app.config.server.keepUploadExtensions
# 	app.config.server.uploadDir
# 
# **@param function callback** <br/>
#  Callback to call after data has been retrieved
# <hr/>

IncomingMessage::getPostData = (callback) ->
	req = this
	res = @__response
	app = @__app
	if req.headers['content-type']?
		form = req.__incomingForm = new app.modules.formidable.IncomingForm()
		form.uploadDir = "#{app.path}/" + app.config.server.uploadDir.replace(app.regex.startOrEndSlash, "") + "/"
		form.maxFieldsSize = app.config.server.maxFieldSize
		form.encoding = 'utf-8'
		form.keepExtensions = app.config.server.keepUploadExtensions
		form.parse req, (err, fields, files) ->
			
			if err
				app.rawServerError res, [ req.__urlData.pathname, err ] 
			else 
				callback.call req, fields, files
			null
	else
		app.badRequest res
	null


# ## exceededUploadLimit
# 
# 	()
# 
# Checks the Content-Type header to verify if the maximum upload limit has exceeded
# 
# **@returns boolean** <br/>
#  True if upload limit (app.config.server.maxUploadSize) has exceeded
# <hr/>

IncomingMessage::exceededUploadLimit = ->
	if @headers['content-length']?
		bytesExpected = parseInt @headers['content-length'], 10
		uploadSize = @__app.config.server.maxUploadSize
		if bytesExpected > uploadSize
			@__app.emit 'upload_limit_exceeded', this, @__response
			if @__stopRoute is true then return true
			@__response.rawHttpMessage
				statusCode: 400
				message: "Upload limit exceeded: #{uploadSize/(1024*1024)} MB."
				raw: true
			true 
		else 
			false
	else
		false


# ## stopRoute
# 
# 	()
# 
# Stops the current route processing. A response *must* be sent if the request is stopped.
# <hr/>

IncomingMessage::stopRoute = ->
	@__stopRoute = true

# <br/>