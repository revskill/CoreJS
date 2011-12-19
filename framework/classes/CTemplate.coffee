
# # CTemplate
# 
# Template creation and parsing. Available as **app.template**
#
# **@uses**
#
# - [coffee-script](https://github.com/jashkenas/coffee-script)
#
# <hr/><br/>

class CTemplate
	
	openTag = closeTag = viewCache = null
	fnOpen = /\(function\(\) \{\s+/
	fnClose = /\s+\}\);$/
	newLine = /\n/g
	startSpaces = /^[ ]+/g
	unixShebang = /^#!(.*?)\s+/

	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>
	
	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
		openTag = '<?'
		closeTag = '?>'
		viewCache = {}
	
	
	# ## render
	# 
	# 	(data, vars, context, relPath, partialView)
	# 
	# Renders a template, creating a render function
	# 
	# **@param string data** <br/>
	#  Buffer containing the template code <br/>
	# **@param vars** <br/>
	#  Variables to use <br/>
	# **@param context** <br/>
	#  Object to use as context <br/>
	# **@param relPath** <br/>
	#  Relative path of the template file <br/>
	# **@param boolean partialView** <br/>
	#  Whether or not it's a partial view <br/>
	# **@returns function** <br/>
	#  Render Function
	# <hr/>
	
	render: (data, vars, context, relPath, partialView) ->
		data = data.replace unixShebang, ''
		stringRegex = new RegExp(/('|")(.*?)('|")/g)
		search = @searchPattern data, [ openTag, closeTag ]
		openPos = search[openTag]
		closePos = search[closeTag]
		vars ?= {}
		
		if not partialView and @app.viewCaching
			if framework.util.isTypeOf(@app.views.callbacks[relPath], 'function')
				f = @app.views.callbacks[relPath]
			else
				f = createFunction data, openPos, closePos, relPath
				@app.views.callbacks[relPath] = f if typeof f is 'function'
		else
			f = createFunction data, openPos, closePos, relPath
		
		if partialView
			f
		else
			try
				if typeof f is 'function' then f.call(context, vars) else f
			catch e
				e
		
	
	# ## renderPartial
	# 
	# 	(data, relPath)
	# 
	# Renders a partial view
	# 
	# **@param object data** <br/>
	#  Data to use in the rendering function <br/>
	# **@param relPath** <br/>
	#  Relative path of the template file
	# <hr/>

	renderPartial: (data, relPath) ->
		@render data, null, null, relPath, true


	# ## searchPattern
	# 
	# 	(buffer, s)
	# 
	# Searches for a pattern in a string
	# 
	# **@param buffer** <br/>
	#  Buffer to search in <br/>
	# **@param s** <br/>
	#  Search keyword <br/>
	# **@private**
	# <hr/>

	searchPattern: (buffer, s) ->
		indices = {}
		s = [s] unless framework.modules.util.isArray(s)
		for pat in s
			found = indices[pat] = new Array()
			idx = buffer.indexOf(pat)
			until idx is -1
				found.push idx
				idx = buffer.indexOf pat, (idx+1)
		indices


	# <!-- ============================================================================================ -->
	# # Private Functions <hr/><br/>
	# <!-- ============================================================================================ -->

	# ## escapeString
	# 
	# 	(string)
	# 
	# Escapes a string so it can be used within JavaScript code
	# 
	# **@param string** <br/>
	#  String to escape <br/>
	# **@returns escaped** <br/>
	#  string <br/>
	# **@inner**
	# <hr/>
	
	escapeString = (string) ->
		string.replace('\\','\\\\').replace(/"/g,'\\"').replace newLine, '\\n'


	# ## createFunction
	# 
	# Creates a template rendering function
	# 
	# **@param data** <br/>
	#  Template buffer <br/>
	# **@param openPos** <br/>
	#  Open position <br/>
	# **@param closePos** <br/>
	#  close position <br/>
	# **@param relPath** <br/>
	#  Relative path of the template file <br/>
	# **@returns function** <br/>
	#  Render Function <br/>
	# **@inner**
	# <hr/>

	createFunction = (data, openPos, closePos, relPath) ->
		if openPos.length is closePos.length
			codeSection = tplSection = undefined
			lastPos = 0
			jsVar = '\t__tpl.__buffer'
			jsCode = sprintf("->\n\t__viewPath='%s'\n\t__tpl=locals.__viewInstance\n\n\t`with(locals) { with (__tpl) {`\n\n\t__tpl.__buffer='' # Reset view buffer to reuse view object\n", relPath)
			for i of openPos
				oIndex = openPos[i]
				cIndex = closePos[i]
				tplSection = escapeString data.substring(lastPos, oIndex)
				jsCode += jsVar + "+=\"" + tplSection + "\"\n"
				codeSection = data.substring(oIndex + 2, cIndex).replace(startSpaces,'')
				codeSection = jsVar.trim() + " +" + codeSection if codeSection[0] is '='
				codeSection += "\n"	unless codeSection.match(/\;$/)
				jsCode += '\t' + codeSection
				lastPos = cIndex
				
			jsCode += jsVar + "+=\"" + escapeString(data.substring(cIndex)) + "\"\n\treturn " + jsVar + "\n"
			sanitizeRegex = /([\[\]\.\?\^\{\}\-\$])/g
			openRegex = openTag.replace(sanitizeRegex, "\\$1")
			closeRegex = closeTag.replace(sanitizeRegex, "\\$1")
			replRegex = new RegExp("(" + openRegex + "|" + closeRegex + ")", "g")
			jsCode = jsCode.replace(replRegex, "") + '\n\t`}}`\n\tnull'
			
			# console.exit jsCode
			
			# Compile into raw javascript
			try
				jsCode = framework.modules.coffee.compile jsCode, {bare: true}
				jsCode = jsCode.trim().replace('{;','{').replace fnOpen, ''
				jsCode = jsCode.replace fnClose, ''
				
				# console.exit jsCode
				
			catch e
				return e
			
			try
				return new Function('locals', jsCode)
			catch e
				return e


module.exports = CTemplate

# <br/>
