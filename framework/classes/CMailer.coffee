
# # CMailer
# 
# Mailer Class. Available as **app.mailer**
#
# **@uses**
#
# [nodemailer](http://www.nodemailer.org)
#
# **@extends** EventEmitter
# <hr/><br/>

class CMailer extends framework.modules.events.EventEmitter
	
	# nodemailer.org
	
	send_mail: framework.mailer
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>	

	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
		
module.exports = CMailer

# <br/>