
# # CView
# 
# View helper functions. Available as functions within templates.
#
# <hr/><br/>

class CView
	
	sanitizeMarkdown: true
	
	app: null
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>
	
	constructor: (app, __viewDir) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		Object.defineProperty @, '__viewDir', {value: __viewDir, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
		@__buffer = ''
	
	# ## echo
	# 
	# 	(msg)
	# 
	# Appends a string to the view buffer
	# 
	# **@param msg** <br/>
	#  String to append
	# <hr/>
	
	echo: (msg) ->
		@__buffer += msg

	
	# ## url
	# 
	# 	(path)
	# 
	# Appends a specific URL to the view buffer
	# 
	# **@param url** <br/>
	#  Url to append
	# <hr/>
	
	url: (path) ->
		@app.url path


	# ## sprintf
	# 
	#	(string, ...args)
	#
	# C-Like string substitution and appends to view buffer
	# 
	# **@params mixed** <br/>
	#  Sprintf parameters
	# <hr/>

	printf: ->
		@echo sprintf.apply null, _.values(arguments)

	
	# ## include
	# 
	# 	(template, data)
	# 
	# Includes a partial view and appends to view buffer
	# 
	# **@param template** <br/>
	#  Partial view to include <br/>
	# **@param data** <br/>
	#  Data to use within the partial view
	# <hr/>

	include: (template, data) ->
		origBuf = @__buffer
		template = template.replace(@app.regex.startOrEndSlash, '')
		data ?= {}
		if @app.regex.layoutView.test(template)
			relPath = template.replace(@app.regex.layoutView, '__layout/') + '.tpl'
		else if @app.regex.tplFile.test(template)
			relPath = template
		else unless template.indexOf('/') is -1
			relPath = template.replace(@app.regex.partialViewReplace, '$1$2/_$3.tpl')
		else
			relPath = "#{@__viewDir}/_#{template}.tpl"
		f = @app.partialViews[relPath]
		data.__viewInstance = this
		framework.util.merge data, this
		try
			f.call null, data
			@__buffer = origBuf + @__buffer
			@__buffer = "\n#{@__buffer}\n"
		catch e
			throw new Error "PartialView => #{relPath} #{e.toString()}"
		null


	# ## markdown
	# 
	# 	(string, flags)
	# 
	# Parses markdown syntax and appends to view buffer
	# 
	# **@param string** <br/>
	#  Markdown syntax to parse <br/>
	# **@param array | string | int flags** <br/>
	#  Discount flags
	# <hr/>

	markdown: (string, flags, sanitize=@sanitizeMarkdown) ->
		string = @app.markdown.sanitizer.sanitize(string) if sanitize  # Strip unsafe HTML tags: CRUCIAL
		string = @app.markdown.parse(string, flags) # Parse Markdown
		@__buffer += string # Append to view buffer
		'' # In case the function is being accessed with <?= markdown(...) ?>

module.exports = CView

# <br/>