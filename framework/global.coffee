
# # Globals
# 
# Global variables and shortcuts

# Aliases

global._ = require('underscore')
global._s = require('underscore.string')
global.inspect = framework.modules.util.inspect
global.sprintf = framework.modules.util.format


# Extend console with exit

console.exit = (msg) ->
	if typeof msg is 'string' then console.log(msg) else console.log inspect msg
	process.exit()

# <br/>