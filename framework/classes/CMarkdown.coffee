
# # CMarkdown
# 
# Markdown class. Available as **app.markdown**
# 
# **@uses**
#
# - [Discount](http://www.pell.portland.or.us/~orc/Code/discount/)
# - [node-discount](https://github.com/visionmedia/node-discount)
# - [sanitizer](https://github.com/theSmaw/Caja-HTML-Sanitizer)
# 
# **Markdown Flags Reference**
# 
# 	noLinks				Don’t do link processing, block <a> tags
# 	noImage				Don’t do image processing, block <img>
# 	noPants				Don’t run smartypants()
# 	noHTML				Don’t allow raw html through AT ALL
# 	strict				Disable SUPERSCRIPT, RELAXED_EMPHASIS
# 	tagText				Process text inside an html tag; no <em>, no <bold>, no html or [] expansion
# 	noExt				Don’t allow pseudo-protocols
# 	cdata				Generate code for xml ![CDATA[...]]
# 	noSuperscript		No A^B
# 	noRelaxed			Emphasis htmlens everywhere
# 	noTables			Don’t process PHP Markdown Extra tables.
# 	noStrikethrough		Forbid ~~strikethrough~~
# 	toc					Do table-of-contents processing
# 	md1Compat			Compatability with MarkdownTest_1.0
# 	autolink			Make http://foo.com a link even without <>s
# 	safelink			Paranoid check for link protocol
# 	noHeader			Don’t process document headers
# 	tabStop				Expand tabs to 4 spaces
# 	noDivQuote			Forbid >%class% blocks
# 	noAlphaList			Forbid alphabetic lists
# 	noDlist				Forbid definition lists
# 	extraFootnote		Enable PHP Markdown Extra-style footnotes
#
# <hr/><br/>

class CMarkdown
	
	internalFlags = ['noImage', 'noTables', 'autolink', 'noHTML', 'noExt']
	defaultFlags = ['noImage', 'noTables', 'autolink', 'noHTML', 'noExt']
	
	flags: {}
	sanitizer: framework.modules.sanitizer
	markdown: framework.modules.discount
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>
	
	constructor: (app) ->
		@flags['internal'] ?= internalFlags
		@flags['default'] ?= defaultFlags
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
		@updateFlagBits()


	# ## parse
	# 
	# 	(string, flags)
	# 
	# Parses markdown syntax
	# 
	# **@param string** <br/>
	#  String to parse <br/>
	# **@param array | string | int** <br/>
	#  flags Flags to use <br/>
	# **@returns string** <br/>
	#  Parsed string
	# <hr/>
		
	parse: (string, flags) ->
		if typeof flags is 'number'
			flagSum = flags
		else if typeof flags is 'string'
			flagSum = @flags[flags] or @flags['default'] # Switch to default flags if provided does not exist
		else if framework.modules.util.isArray(flags)
			flagSum = @flagCounter(flags)
		else
			flagSum = @flags.default # use defaults
		@markdown.parse string, flagSum

	
	# ## updateFlagBits
	# 
	# 	()
	# 
	# Updates the flag bits, converts them from text to their respective integers
	# from the Discount module
	# <hr/>

	updateFlagBits: ->
		@flags[key] = @flagCounter(@flags[key], true) for key of @flags
	
	
	# ## flagCounter
	# 
	# 	(flags, exit)
	# 
	# Counts flags available in array
	# 
	# **@param array flags** <br/>
	#  Discount Flags <br/>
	# **@param exit** <br/>
	#  Will exit when a flag is invalid, if set to True <br/>
	# **@returns int** <br/>
	#  Sum of the flag bits
	# <hr/>
	
	flagCounter: (flags, exit=false) ->
		sum = 0
		for flag in flags
			intVal = @markdown.flags[flag]
			unless intVal is undefined then sum += intVal
			else
				if exit
					@app.log "Invalid Discount Flag: #{flag}"
					process.exit()
				else
					@app.log "Invalid Discount Flag: '#{flag}' (using defaults)"
					return @flags.default
		sum


module.exports = CMarkdown

# <br/>