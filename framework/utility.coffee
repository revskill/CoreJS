
# # CUtility
#
# Available as **framework.util**
#
# <hr/><br/>

class CUtility
	
	constructor: (framework) ->
		Object.defineProperty @, 'framework', {value: framework, writable: true, enumerable: false, configurable: true}

	# ## typecast
	# 
	# 	(value)
	# 
	# Automatically detects the type of data contained in value and returns the converted type
	# 
	# **@param value** <br/>
	#  Value to typecast <br/>
	# **@returns mixed** <br/>
	#  Converted value
	# <hr/>

	typecast: (value) ->
		if @framework.regex.integer.test(value)
			parseInt value
		else if @framework.regex.float.test(value)
			parseFloat value
		else if @framework.regex.null.test(value)
			null
		else if @framework.regex.boolean.test(value)
			if value.toLowerCase() is 'true' then true else false
		else
			value
			
	# ## merge
	# 
	# 	(dest, src)
	# 
	# Clones an object with another
	# 
	# **@param object dest** <br/>
	#  Destination object <br/>
	# **@param object src** <br/>
	#  Source object to read properties from <br/>
	# **@returns** <br/>
	#  Cloned object
	# <hr/>
			
	merge: (dest, src) ->
		dest[key] = src[key] for key of src


	# ## getFiles
	# 
	# 	(path, regex)
	# 
	# Retrieves a list of files from path, filtering files using a regular expression
	# 
	# **@param path** <br/>
	#  Path to get files from <br/>
	# **@param RegExp regex** <br/>
	#  Regular expression to filter with. Defaults to framework.regex.jsFile <br/>
	# **@returns array** <br/>
	#  Array of files
	# <hr/>

	getFiles: (path, regex) ->
		regex = @framework.regex.jsFile if regex is undefined
		files = @framework.modules.fs.readdirSync path
		out = []
		for file in files
			out.push file if regex.test(file)
		out

	
	# ## toCamelCase
	# 
	# 	(string)
	# 	
	# Converts a dashed name into camel case
	# 
	# **@param string** <br/>
	#  String to convert <br/>
	# **@returns** <br/>
	#  string in camel case
	# <hr/>

	toCamelCase: (string) ->
		_s.titleize _s.camelize(string.replace(/\_/, '-'))

	
	# ## requireAllTo
	# 
	# 	(path, destination)
	# 
	# Requires class constructors and stores their classNames into the destination object
	# 
	# **@param path** <br/>
	#  Path to scan for classes <br/>
	# **@param object** <br/>
	#  destination Object to store the class constructors in
	# <hr/>

	requireAllTo: (path, destination) ->
		files = @getFiles(path)
		replRegex = /(\..*)?$/
		
		for file in files
			key = file.replace replRegex, ''
			file = file.replace @framework.regex.jsFile, ''
			continue if ignore? and key in ignore
			classConstructor = require "#{path}/#{file}"
			destination[key] = classConstructor if typeof classConstructor is 'function'
		null
		
		
	# ## ls
	# 
	# 	(path, regex)
	# 
	# Retrieves a list of files from path, filtering files using a regular expression
	# 
	# **@param path** <br/>
	#  Path to get files from <br/>
	# **@param RegExp regex** <br/>
	#  Regular expression to filter with. <br/>
	# **@returns** <br/>
	#  array Array of files
	# <hr/>

	ls: (path, regex) ->
		files = @framework.modules.fs.readdirSync(path)
		out = []
		if regex? then out.push file for file in files when regex.test file
		out


	# ## isTypeOf
	# 
	# 	(val, type)
	# 
	# Compares the type of a variable
	# 
	# **@param val** <br/>
	#  Value to check <br/>
	# **@param type**  <br/>
	# Type to check against <br/>
	# **@returns bool** <br/>
	#  True if the value is of type
	# <hr/>

	isTypeOf: (val, type) ->
		typeof val is type


	# ## strRepeat
	# 
	# 	(input, multiplier)
	#
	# PHP's str_repeat
	# 
	# **@param input** <br/>
	#  String to repeat <br/>
	# **@param int multiplier** <br/>
	#  Times to repeat the input string <br/>
	# **@returns** <br/>
	#  string String after the multiplication process
	# <hr/>

	strRepeat:  (input, multiplier) ->
		new Array(multiplier + 1).join input

	
	# ## parseRange
	# 
	# 	(size, str)
	# 	
	# Parses an Accept-Range header.
	# 
	# Uses code from connect's [util.js](https://github.com/senchalabs/connect/blob/master/lib/utils.js)
	# 
	# **@param size** <br/>
	#  Size in bytes <br/>
	# **@param str** <br/>
	#  Accept-Header string <br/>
	# **@returns array** Array of bytes <br/>
	# <hr/>
	
	parseRange: (size, str) ->
		valid = true
		arr = str.substr(6).split(',').map (range) ->
			range = range.split '-'
			start = parseInt range[0], 10
			end = parseInt range[1], 10
		
			# -500
			if isNaN(start)
				start = size - end
				end = size - 1
			# 500-
			else if isNaN(end)
				end = size - 1
			
			# Invalid
			valid = false if isNaN(start) or isNaN(end) or start > end
			
			{start: start, end: end}
		
		if valid then arr else null
		

module.exports = CUtility

# <br/>