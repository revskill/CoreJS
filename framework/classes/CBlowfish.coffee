
# # CBlowfish
# 
# Blowfish Encryption class. Available as **app.blowfish**
#
# **@uses**
#
# - [node.bcrypt.js](https://github.com/ncb000gt/node.bcrypt.js)
#
# <hr/><br/>

class CBlowfish
	
	rounds: 10
	seedLength: 20
	bcrypt: framework.modules.bcrypt

	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>

	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
	
	
	# ## genSalt
	# 
	# 	(callback)  [err, salt]
	# 
	# Generates a random salt
	# 
	# **@uses:**
	# 
	# 	CBlowfish::rounds
	# 	CBlowfish::seedLength
	# 
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>

	genSalt: (callback) ->
		@bcrypt.gen_salt @rounds, @seedLength, callback  # (err, salt) ->
	
	
	# ## hashPassword
	# 
	# 	(password, callback)  [err, hash]
	# 
	# Hashes a password using the Blowfish algorithm
	# 
	# **@param password** <br/>
	#  Password to hash <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>

	hashPassword: (password, callback) ->
		@bcrypt.gen_salt @rounds, @seedLength, (err, salt) => 
			@bcrypt.encrypt password, salt, callback  # (err, hash) ->
				
	
	# ## checkPassword
	# 
	# 	(password, hash, callback)  [err, same]
	# 
	# Checks a password against a Blowfish Hash
	# 
	# **@param password** <br/>
	#  Password to check <br/>
	# **@param hash** <br/>
	#  Hash to compare against <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>
	
	checkPassword: (password, hash, callback) ->
		@bcrypt.compare password, hash, callback  # (err, same) ->

	
module.exports = CBlowfish

# <br/>