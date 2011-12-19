
# # CSession
# 
# Session handling and storage. Available as **app.session**
#
# **@uses**
#
# - [hiredis](https://github.com/pietern/hiredis-node)
# - [node-redis](https://github.com/mranney/node_redis)
# - [node-uuid](https://github.com/broofa/node-uuid)
#
# <hr/><br/>

class CSession
	
	typecastVars: []
	sessCookie: "_sess"
	hashCookie: "_shash"
	defaultUserAgent: "Mozilla"
	salt: "$28b28fc2ebcd355ca1a2be8881e888a.67a42975e1626d59434e576b5c63f3483!"

	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>

	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		Object.defineProperty @, 'redis', {value: app.redisClients.sessionStore, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name


	# ## create
	# 
	# 	(req, res, data, persistent, callback)  [sessionData]
	# 
	# Creates a session
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param object** <br/>
	#  Session data to store <br/>
	# **@param boolean persistent** <br/>
	#  Will make the session persistent if set to True <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>
	
	create: (req, res, data, persistent, callback) ->
		guest = null
		if persistent is 'guest'
			guest = true
			persistent = 1
		self = this
		
		@app.debug if guest then 'Creating guest session' else 'Creating session'
		
		userAgent = req.headers['user-agent'] or @defaultUserAgent
		userAgentMd5 = @md5 userAgent
		hashes = @createHash userAgent, guest
		expires = (if persistent then @app.config.session.permanentExpires else (if guest then @app.config.session.guestExpires else @app.config.session.temporaryExpires))
		unless guest
			data = _.extend(data,
				fpr: hashes.fingerprint
				ua_md5: userAgentMd5
				pers: (if persistent then 1 else 0)
			)
		multi = @redis.multi()
		multi.del req.getCookie(@sessCookie) if not guest and req.__session.guest and req.hasCookie(@sessCookie)
		multi.hmset hashes.sessId, data
		multi.expire hashes.sessId, expires
		multi.exec (err, replies) =>
			unless err
				res.setCookie self.sessCookie, hashes.sessId,
					expires: (if persistent then @app.config.session.permanentExpires else null)

				unless guest
					res.setCookie self.hashCookie, hashes.fingerprint,
						expires: @app.config.session.regenInterval
				data.guest = parseInt(data.guest) if guest
				data = self.typecast(data)
				req.__session = data
				req.__origSessionState = _.extend({}, data)
				req.__sessionJson = JSON.stringify(data)
				@app.emit 'session_load', req, res
				callback.call self, data

	
	# ## destroy
	# 
	# 	(req, res, callback)  []
	# 
	# Destroys a session
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	destroy: (req, res, callback) ->
		@app.debug 'Destroying session'
		if req.hasCookie(@sessCookie) and req.__session
			self = this
			sessId = req.getCookie(@sessCookie)
			fingerprint = @getFingerprint(req, sessId)
			if fingerprint is req.__session.fpr
				@redis.del sessId, (err, reply) =>
					unless err or reply isnt 1
						res.removeCookies [ self.sessCookie, self.hashCookie ]
						callback.call self
			else
				res.removeCookies [ @sessCookie, @hashCookie ]
				@app.login res
		else
			@app.login res
		null
	
	
	# ## loadSession
	# 
	# 	(req, res, callback)  []
	# 
	# Loads a session from Redis
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res HTTP** <br/>
	#  Response <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	loadSession: (req, res, callback) ->
		if req.__loadedSession is true
			# already did load session
			callback.call this
			return
		else
			# Load new session
			req.__loadedSession = true
		
		self = this
		sessId = req.getCookie(@sessCookie)
		sessHash = req.getCookie(@hashCookie)
		fingerprint = self.getFingerprint(req, sessId)
		if sessId
			@redis.hgetall sessId, (err, data) =>
				guest = not data.user?
				if err
					@app.serverError res, [ 'REDIS SERVER', err ]
				else if _.isEmpty(data)
					res.removeCookie self.hashCookie
					self.createGuestSession req, res, callback
				else
					data.guest = parseInt(data.guest) if guest
					data.pers = parseInt(data.pers)	unless guest
					data = self.typecast(data)
					if guest
						@app.debug 'Loading guest session'
						req.__session = data
						req.__origSessionState = _.extend({}, data)
						req.__sessionJson = JSON.stringify(data)
						@app.emit 'session_load', req, res
						callback.call self
					else if sessHash
						if sessHash is fingerprint and sessHash is data.fpr
							@app.debug 'Loading session'
							req.__session = data
							req.__origSessionState = _.extend({}, data)
							req.__sessionJson = JSON.stringify(data)
							@app.emit 'session_load', req, res
							callback.call self
						else
							req.removeCookies [ self.sessCookie, self.hashCookie ]
							@app.login res
					else
						userAgent = req.headers['user-agent'] or self.defaultUserAgent
						ua_md5 = self.md5(userAgent)
						if ua_md5 is data.ua_md5
							hashes = self.createHash(userAgent)
							newSess = hashes.sessId
							newHash = hashes.fingerprint
							expires = @app.config.session[(if data.pers then 'permanentExpires' else (if data.user then 'temporaryExpires' else 'guestExpires'))]
							multi = @redis.multi()
							multi.hset sessId, 'fpr', newHash
							multi.rename sessId, newSess
							multi.expire newSess, expires
							multi.exec (err, replies) =>
								if err
									@app.serverError res, [ 'REDIS SERVER', err ]
								else if replies[1] is 'OK' and replies[2] is 1
									res.setCookie self.sessCookie, newSess,
										expires: (if data.pers then expires else undefined)

									res.setCookie self.hashCookie, newHash,
										expires: @app.config.session.regenInterval

									req.__cookies[self.sessCookie.toLowerCase()] = newSess
									data.fpr = req.__cookies[self.hashCookie.toLowerCase()] = newHash
									req.__session = data
									req.__origSessionState = _.extend({}, data)
									req.__sessionJson = JSON.stringify(data)
									@app.emit 'session_load', req, res
									@app.debug 'Regenerating session'
									callback.call self
								else
									@app.serverError res, [ 'REDIS SERVER', "Error regenerating session: #{sessId}" ]
						else
							res.removeCookies [ self.sessCookie, self.hashCookie ]
							@app.login res
		else if @app.config.session.guestSessions
			res.removeCookie @hashCookie
			@createGuestSession req, res, callback
		else
			res.removeCookie @hashCookie if sessHash
			req.__session = req.__origSessionState = {}
			req.__sessionJson = ''
			@app.emit 'session_load', req, res
			callback.call self


	# ## createGuestSession
	# 
	# 	(req, res, callback)  []
	# 
	# Creates a guest session
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param res** <br/>
	#  HTTP Response <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	createGuestSession: (req, res, callback) ->
		self = this
		@create req, res, {guest: '1'}, "guest", (data) ->
			callback.call self

	
	# ## getFingerprint
	# 
	# 	(req, sessId)
	# 
	# Gets a session fingerprint
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param sessId** <br/>
	#  Session ID <br/>
	# **@returns** <br/>
	#  md5 hash of the session fingerprint
	# <hr/>

	getFingerprint: (req, sessId) ->
		userAgent = req.headers['user-agent'] or @defaultUserAgent
		@md5 (userAgent + sessId + @salt)


	# ## md5
	# 
	# 	(string)
	# 
	# Hashes a string using the MD5 algorithm
	# 
	# **@param string** <br/>
	#  String to hash <br/>
	# **@returns string** <br/>
	#  MD5 hash of the string
	# <hr/>

	md5: (string) ->
		framework.modules.crypto.createHash('md5').update(string).digest 'hex'

	
	# ## createHash
	# 
	# 	(userAgent, guest)
	# 
	# Creates a session hash
	# 
	# **@param userAgent** <br/>
	#  String representing the client's User Agent <br/>
	# **@param boolean guest** <br/>
	#  Whether or not it's a guest session
	# <hr/>

	createHash: (userAgent, guest) ->
		sessId = @md5 framework.modules.node_uuid()
		if guest
			{sessId: sessId}
		else
			fingerprint = @md5(userAgent + sessId + @salt)
			{sessId: sessId,  fingerprint: fingerprint}

	
	# ## typecast
	# 
	# 	(data)
	# 
	# Typecasts all the values in an object
	# 
	# **@param object data** <br/>
	#  Object containing key/value pairs to be typecasted <br/>
	# **@returns** <br/>
	#  Object with typecasted values
	# <hr/>

	typecast: (data) ->
		for key in @typecastVars
			data[key] = framework.util.typecast(data[key]) if data[key]?
		data


module.exports = CSession

# <br/>