
class MainController extends framework.classes.CController
	
	authRequired: false
	
	@route '/', (req, res) -> res.render 'index'
		

module.exports = MainController