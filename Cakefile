
# CoreJS Cakefile
# ======================

watchFiles = ['master.coffee', 'staging', 'production.coffee', 'framework', 'app']

fs = require 'fs'
{spawn, exec} = require 'child_process'

logCallback = (data) -> if data? then console.log  data.toString().trim()

getFiles = (callback) ->
	find = exec 'find . | grep "\\.coffee$"', (error, stdout, stderr) ->
		unless error then callback.call this, stdout.split('\n')
		else throw error

	
task 'build', 'Build project', ->
	coffee = spawn 'coffee', [ '-b', '-c', watchFiles...]
	coffee.stdout.on 'data', logCallback
	

task 'watch', 'Watch Project', ->
	coffee = spawn 'coffee', [ '-b', '-c', '-w', watchFiles...]
	coffee.stdout.on 'data', logCallback
	

task 'clean', 'Clean Project', ->
	getFiles (data) ->
		command = ['rm -vf']
		nodeModules = /\/node_modules\//
		hidden = /^\.\/\./
		coffeeFile = /\.coffee$/
		command.push item.replace(coffeeFile, '.js') for item in data when not nodeModules.test(item) and not hidden.test(item)
		exec command.join(' '), (err, stdout, stderr) -> if err then throw err else console.log stdout
		
task 'doc', 'Build Docs', ->
	extraCSS = '''
/* CSS Overrides */
td.docs, th.docs { overflow: auto !important; }
'''
	
	command = "
rm -Rf docs;
docco framework/*.coffee framework/classes/*.coffee;
"
	exec command, ->
		
		# Patch index.html
		indexBuf = fs.readFileSync 'docs/index.html', 'utf-8'
		fs.writeFileSync 'docs/index.html', indexBuf.replace(/index\.coffee/g, 'CoreJS Documentation'), 'utf-8'
		
		# Patch doc files
		files = fs.readdirSync 'docs'
		htmlFile = /\.html$/
		title = /<h1>(\s+)(.*?)(\s+)<\/h1>/
		for file in files
			if file is 'index.html' or not htmlFile.test(file) then continue
			buf = fs.readFileSync "docs/#{file}", 'utf-8'
			fs.writeFileSync "docs/#{file}", buf.replace(title, '<br/><p><a style="text-decoration: none; font-size: 14px; font-weight: normal; background: #f5f5ff; padding: 3px 5px; border-radius: 5px; border: solid 1px #d3d3dc;" href="index.html">&larr; Back to index</a></p>'), 'utf-8'
		
		# Patch css
		doccoCSS = fs.readFileSync "docs/docco.css", 'utf-8'
		fs.writeFileSync "docs/docco.css", (doccoCSS + extraCSS), 'utf-8'