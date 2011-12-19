
# Debug the view caching functionality of the application.

ViewCacheDebug = (app) ->

	app.on 'view_cache_access', (app, relPath) -> app.log "Using cached function for #{relPath}"
	app.on 'view_cache_store', (app, relPath) -> app.log "Storing new function for #{relPath}"
	app.on 'mvc_request', (req, res) -> res.on 'finish', -> console.log '-'

module.exports = ViewCacheDebug
