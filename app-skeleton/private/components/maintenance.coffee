
Maintenance = (app) ->
	
	app.on 'request', (req, res) =>
		req.__stopRoute = on
		if req.method is 'GET'
			res.render '#maintenance', on 
		else 
			res.end ''
	
module.exports = Maintenance