
# # CCSRFProtect
# 
# Cross-Site Request Forgery Protection. Available as **app.csrf**
# <hr/><br/>

class CCSRFProtect
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>

	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
	
	# ## getToken
	# 
	# 	(req, context)
	# 
	# Retrieves a CSRF token
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param context** <br/>
	#  Context to retrieve <br/>
	# **@returns** <br/>
	#  md5 hash of the token
	# <hr/>
		
	getToken: (req, context) ->
		return '' unless @app.config.session.guestSessions

		session = req.__session
		key = "csrf_#{context}"

		if session[key]?
			session[key]
		else
			session[key] = @app.session.md5 Math.random().toString()


	# ## checkToken
	# 
	# 	(req, context, token)
	# 
	# Checks a given token with its context
	# 
	# **@param req** <br/>
	#  HTTP Request <br/>
	# **@param context** <br/>
	#  Context to check against <br/>
	# **@param token** <br/>
	#  md5 token to check <br/>
	# **@returns boolean** <br/>
	#  True if token check was successful
	# <hr/>

	checkToken: (req, context, token) ->
		return true unless @app.config.session.guestSessions

		session = req.__session
		key = "csrf_#{context}"
		
		if session[key]?	
			if session[key] is token
				true
			else
				@app.emit 'csrf_check_fail', req, context, token
				@app.log '[SECURITY WARNING]', "Potential CSRF Attack coming from #{req.socket.remoteAddress}"
				null
		else
			null


module.exports = CCSRFProtect

# <br/>