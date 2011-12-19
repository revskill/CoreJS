
# Ignores listenPort from Requests. Useful if running with a Reverse Proxy,
# to hide the real port in which the application is running.

PortBlock = (app) ->
	
	app.on 'request', (req, res) -> req.stopRoute() if req.headers.host.indexOf(':') >= 0
	
module.exports = PortBlock