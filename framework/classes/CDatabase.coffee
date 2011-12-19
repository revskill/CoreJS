
# # CDatabase
# 
# MySQL Database helper functions. Available as **app.db**
#
# Supports Cache storage and invalidation features for all its methods. 
#
# **@uses**
#
# - [node-mysql](https://github.com/felixge/node-mysql)
#
# <hr/><br/>

class CDatabase
	
	regex = { endingComma: /, ?$/ }
	isArray = framework.modules.util.isArray
	
	queryCache: {}
	maxCacheTimeout: 1 * 365 * 24 * 3600  # Expire in 1 year (seconds)
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>
		
	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		Object.defineProperty @, 'client', {value: app.mysqlClient, writable: true, enumerable: false, configurable: true}
		Object.defineProperty @, 'redis', {value: app.redisClients.cacheStore, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name
			
		# Monkey-patch @client.query to support cache
		@client.__query = @client.query
		@client.query = cachedQuery
	
	# ## query
	# 
	# 	(sql, params, appendSql, callback)  [err, results, fields]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Performs a manual SQL Query
	# 
	# **@example**
	# 
	# 	db.query 'SELECT * FROM table WHERE id=? AND user=?', [id, user], (err, results, fields) -> callback.call err, results, fields
	# 	
	# **@param sql** <br/>
	#  SQL code to execute <br/>
	# **@param array params** <br/>
	#  Array of parameters, representing the sequential ? replacements in query <br/>
	# **@param appendSql** <br/>
	#  Additional SQL Code to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>
	
	query: (sql, params, appendSql, callback) ->
		unless typeof sql is 'string' then cdata = sql; sql = sql.param  # process special cache query
		unless callback?
			callback = appendSql
			appendSql = ''
		params = [params] unless isArray(params)  # accept single value params
		args = [ "#{sql} #{appendSql}".trim(), params, callback ]
		args.unshift cdata if cdata?  # append cache data if available
		@client.query.apply this, args

	# ## exec
	#
	# 	(query, params, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Performs a query that returns no results. Usually affecting tables/rows
	# 
	# **@example**
	#
	# 	db.exec 'CREATE TABLE test_db (id AUTO_INCREMENT NOT NULL, PRIMARY KEY (id)', [], (err, info) -> console.log [err, info]
	# 	db.exec 'CREATE TABLE test_db (id AUTO_INCREMENT NOT NULL, PRIMARY KEY (id)', (err, info) -> console.log [err, info]
	# 
	# **@param sql** <br/>
	#  SQL code to execute <br/>
	# **@param array params** <br/>
	#  Query parameters <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>
	
	exec: (query, params, callback) ->
		unless typeof query is 'string' then cdata = query; query = query.param  # process special cache query
		unless callback?
			callback = params
			params = []
		else unless isArray(params) # accept single value params
			params = [params]
		
		args = [query, params]
		args.push (err, info) => callback.call @app, err, info
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args
	
	
	# ## queryWhere
	# 
	# 	(cond, params, table, columns, appendSql, callback)   [err, results, fields]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Performs a `SELECT ... WHERE ...` query
	# 
	# **@example**
	#
	# 	db.queryWhere 'user=?, pass=?', [user, pass], 'users', 'id,user,pass,info', (err, results, fields) -> console.log results
	# 	db.queryWhere 'user=?, pass=?', [user, pass], 'users', (err, results, fields) -> console.log results
	# 
	# **@param cond** <br/>
	#  Valid SQL query condition <br/>
	# **@param params** <br/>
	#  Query parameters <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>
	
	queryWhere: (cond, params, table, columns, appendSql, callback) -> # optional columns & appendSql
		unless typeof cond is 'string' then cdata = cond; cond = cond.param  # process special cache query
		unless appendSql?
			callback = columns
			columns = '*'
			appendSql = ''
		else if callback is undefined
			callback = appendSql
			appendSql = ''
			
		params = [params] unless isArray(params) # accept single value params
		
		args = ["SELECT #{columns} FROM #{table} WHERE #{cond} #{appendSql}".trim(), params]
		args.push (err, results, fields) => callback.call @app, err, results, fields
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args


	# ## queryField
	# 
	# 	(columns, table, appendSql, callback)   [err, results, fields]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Queries specific columns from a table
	# 
	# **@example**
	#
	# 	db.queryField 'username', 'users', (err, results, fields) -> console.log results
	# 	
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	queryField: (columns, table, appendSql, callback) ->
		unless typeof columns is 'string' then cdata = columns; columns = columns.param  # process special cache query
		unless callback?
			callback = appendSql
			appendSql = ''
		
		args = ["SELECT #{columns} FROM #{table} #{appendSql}".trim()]
		args.push (err, results, fields) => callback.call @app, err, results, fields
		args.unshift cdata if cdata?  # append cache data if available
			
		@client.query.apply this, args


	# ## queryById
	# 
	# 	(id, table, columns, appendSql, callback)  [err, results, fields]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Queries fields by ID
	# 
	# **@example**
	# 
	# 	db.queryById [1,2,3], 'users', 'id,username,password', (err, results, fields) -> console.log results
	# 	db.queryById 1, 'users', 'id,username,password', (err, results, fields) -> console.log results
	# 	db.queryById 1, 'users', (err, results, fields) -> console.log results
	# 
	# **@param id array | int** <br/>
	#  Id(s) to query <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	queryById: (id, table, columns, appendSql, callback) ->
		unless typeof id is 'number' or isArray(id) then cdata = id; id = id.param  # process special cache query
		unless appendSql?
			callback = columns
			columns = '*'
			appendSql = ''
		else if callback is undefined
			callback = appendSql
			appendSql = ''
		id = [id] if typeof id is 'number'
		
		args = ["id IN (#{id.toString()})", [], table, columns, appendSql, callback]
		
		if cdata? # Inject cdata to first parameter (forwarding cdata to next function)
			cdata.param = args[0]
			args[0] = cdata
		
		@queryWhere.apply this, args

	
	# ## queryAll
	# 
	# 	(table, columns, appendSql, callback)  [err, results, fields]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Queries all the entries from a table
	# 
	# **@example**
	# 
	# 	db.queryAll 'users', 'id, username, password', 'DESC', (err, results, fields) -> console.log [err, results, fields]
	# 	db.queryAll 'users', 'id, username, password', (err, results, fields) -> console.log [err, results, fields]
	# 	db.queryAll 'users', (err, results, fields) -> console.log [err, results, fields]
	# 
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function** <br/>
	#  callback Callback to run upon completion
	# <hr/>

	queryAll: (table, columns, appendSql, callback) ->
		unless typeof table is 'string' then cdata = table; table = table.param  # process special cache query
		unless appendSql?
			callback = columns
			columns = '*'
			appendSql = ''
		else if callback is undefined
			callback = appendSql
			appendSql = ''
			
		args = ["SELECT #{columns} FROM #{table} #{appendSql}".trim(), []]
		args.push (err, results, fields) => callback.call @app, err, results, fields
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args


	# ## insertInto
	# 
	# 	(table, fields, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Inserts values into a table
	# 
	# **@example**
	# 
	# 	db.insertInto 'users', [null, 'ernie', 'password'], (err, info) -> console.log info
	# 	db.insertInto 'users', {name: 'ernie', password: 'password'}, (err, info) -> console.log info
	# 
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param array | object fields** <br/>
	#  Fields to insert <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	insertInto: (table, fields, callback) ->
		unless typeof table is 'string' then cdata = table; table = table.param  # process special cache query
		if isArray(fields)
			# Using an array of values
			params = framework.util.strRepeat('?, ', fields.length).replace(regex.endingComma, '')
			
			args = ["INSERT INTO #{table} VALUES(#{params})", fields]
		else
			# Using an object with fields to set
			query = "INSERT INTO #{table} SET "
			fields.id = null if fields.id is undefined # keep primary key in order
			query += "#{key}=?, " for key of fields
			query = query.replace regex.endingComma, ''
			
			args = [query, _.values(fields)]
			
		args.push (err, info) => callback.call @app, err, info
		args.unshift cdata if cdata?  # append cache data if available
			
		@client.query.apply this, args


	# ## deleteById
	# 
	# 	(id, table, appendSql, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Deletes records by ID
	# 
	# **@example**
	# 
	# 	db.deleteById [1,2,3], 'users', (err, info) -> console.log info
	# 	db.deleteById 1, 'users', (err, info) -> console.log info
	# 
	# **@param array | int id** <br/>
	#  Id(s) to delete <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	deleteById: (id, table, appendSql, callback) ->
		unless typeof id is 'number' or isArray(id) then cdata = id; id = id.param  # process special cache query
		unless callback? then callback = appendSql; appendSql = ''
		id = [id] if typeof id is 'number'
		
		args = ["id IN (#{id.toString()})", [], table, appendSql, callback]
		
		if cdata? # Inject cdata to first parameter (forwarding cdata to next function)
			cdata.param = args[0]
			args[0] = cdata
		
		@deleteWhere.apply this, args


	# ## deleteWhere
	# 
	# 	(cond, params, table, appendSql, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Performs a `DELETE ... WHERE ...` query
	# 
	# **@example**
	# 
	# 	db.deleteWhere 'user=?, pass=?', [user, pass], 'users', (err, info) -> console.log results
	# 	
	# **@param cond** <br/>
	#  SQL Condition <br/>
	# **@params params** <br/>
	#  Parameters to use <br/>
	# **@params table** <br/>
	#  Table to use <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	deleteWhere: (cond, params, table, appendSql, callback) ->
		# `DELETE FROM table WHERE id=1`
		unless typeof cond is 'string' then cdata = cond; cond = cond.param  # process special cache query
		unless callback? then callback = appendSql; appendSql = ''
		params = [params] unless isArray(params) # accept single value params
		
		args = ["DELETE FROM #{table} WHERE #{cond} #{appendSql}", params]
		args.push (err, info) => callback.call @app, err, info
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args


	# ## updateById
	# 
	# 	(id, table, values, appendSql, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Updates records by ID
	# 
	# **@example**
	# 
	# 	db.updateById [1,2,3], 'users', {user: 'ernie', pass: 'password'}, 'LIMIT 1', (err, info) -> console.log [err, info]
	# 	db.updateById [1,2,3], 'users', {user: 'ernie', pass: 'password'}, (err, info) -> console.log [err, info]
	# 
	# **@param array | int id** <br/>
	#  Id(s) to update <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param object** <br/>
	#  Values to update, organized in key:value pairs <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	updateById: (id, table, values, appendSql, callback) ->
		unless typeof id is 'number' or isArray(id) then cdata = id; id = id.param  # process special cache query
		unless callback? then callback = appendSql; appendSql = ''
		id = [id] if typeof id is 'number'
		
		args = ["id IN (#{id.toString()})", [], table, values, appendSql, callback]
		
		if cdata? # Inject cdata to first parameter (forwarding cdata to next function)
			cdata.param = args[0]
			args[0] = cdata
		
		@updateWhere.apply this, args

	
	# ## updateWhere
	# 
	# 	(cond, params, table, values, appendSql, callback)  [err, info]
	# 	
	# 	Cache: Invalidate / {invalidate, param}
	# 
	# Performs an `UPDATE ... WHERE ...` query
	# 
	# **@example**
	# 
	# 	db.updateWhere 'user=?, pass=?', [user, pass], 'users', {user: 'ernie', pass: 'password'}, 'LIMIT 1', (err, info) -> console.log [err, info]
	# 	db.updateWhere 'user=?, pass=?', [user, pass], 'users', {user: 'ernie', pass: 'password'}, (err, info) -> console.log [err, info]
	# 
	# **@param cond** <br/>
	#  SQL Condition <br/>
	# **@param params** <br/>
	#  Parameters to use <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param object** <br/>
	#  Values to update, organized in key:value pairs <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>
	
	updateWhere: (cond, params, table, values, appendSql, callback) ->
		# `UPDATE table SET a=1, b=2 WHERE id=23 AND user='ernie' LIMIT 1`
		unless typeof cond is 'string' then cdata = cond; cond = cond.param  # process special cache query
		query = "UPDATE #{table} SET "
		unless callback? then callback = appendSql; appendSql = ''
		params = [params] unless isArray(params) # accept single value params
		query += "#{key}=?, " for key of values
		query = query.replace regex.endingComma, ''
		query += " WHERE #{cond} #{appendSql}"
		
		args = [query, _.values(values).concat(params)]
		args.push (err, info) => callback.call @app, err, info
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args


	# ## countRows
	# 
	# 	(table, callback)  [err, count]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Counts rows in a table
	# 
	# **@example**
	# 
	# 	db.countRows 'users', (err, count) -> console.log [err, count]
	# 	
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>
	
	countRows: (table, callback) ->
		# `SELECT COUNT('') FROM table AS total`
		unless typeof table is 'string' then cdata = table; table = table.param  # process special cache query
		
		args = ["SELECT COUNT('') AS total FROM #{table}", []]
		args.push (err, results, fields) =>
			args = if err then [err, null] else [err, results[0].total]
			callback.apply @app, args
		args.unshift cdata if cdata?  # append cache data if available
		
		@client.query.apply this, args


	# ## idExists
	# 
	# 	(id, table, columns, callback)  [err, exists]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Performs a query by ID, returning an object with the found ID's.
	#
	# This function's behavior varies depending on input:
	#
	#  a) If id is int: exists is `boolean`<br/>
	#  b) If id is array: exists is `object`
	# 
	# **@example**
	# 
	# 	db.idExists [1,2,3], 'users' (err, exists) -> console.log [err, exists]  # --> returns err, object
	# 	db.idExists 1, 'users', (err, exists) -> console.log [err, exists]  # --> returns err, boolean
	# 
	# **@param array | int id** <br/>
	#  Id(s) to check <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion
	# <hr/>

	idExists: (id, table, columns, callback) ->
		unless typeof id is 'number' or isArray(id) then cdata = id; id = id.param  # process special cache query
		unless callback? then callback = columns; columns = '*'
		id = [id] if typeof id is 'number'
		
		args = [id, table, columns]
		args.push (err, results, fields) =>
			if err then callback.call @app, err, null
			else
				if id.length is 1 then callback.call @app, null, results[0]
				else
					found = []; records = {}; exists = {};
					for result, i in results
						found.push result.id
						records[result.id] = results[i]
					for num in id
						exists[num] = if num in found then records[num] else null
					callback.apply @app, [null, exists]
			null

		if cdata? # Inject cdata to first parameter (forwarding cdata to next function)
			cdata.param = args[0]
			args[0] = cdata
		
		@queryById.apply this, args

	
	# ## recordExists
	# 
	# 	(cond, params, table, columns, appendSql, callback)  [err, exists, found]
	# 	
	# 	Cache: Store / {cacheId, timeout, param}
	# 
	# Checks if a record exists
	# 
	# **@example**
	# 
	# 	db.recordExists 'id=?', [1], 'users', 'id, user, pass', 'LIMIT 1', (err, exists, found) -> console.log [err, exists, found]
	# 	db.recordExists 'id=?', [1], 'users', 'LIMIT 1', (err, exists, found) -> console.log [err, exists, found]
	# 
	# **@param cond** <br/>
	#  SQL Condition <br/>
	# **@param params** <br/>
	#  Parameters to check <br/>
	# **@param table** <br/>
	#  Table to use <br/>
	# **@param columns** <br/>
	#  Columns to retrieve <br/>
	# **@param appendSql** <br/>
	#  SQL to append to the query <br/>
	# **@param function callback** <br/>
	#  Callback to run upon completion 
	# <hr/>

	recordExists: (cond, params, table, columns, appendSql, callback) ->
		unless typeof cond is 'string' then cdata = cond; cond = cond.param  # process special cache query
		unless appendSql? then callback = columns; columns = '*'; appendSql = ''
		else if callback is undefined then callback = appendSql; appendSql = ''

		params = [params] unless isArray(params) # accept single value params
		
		args = [cond, params, table, columns, appendSql]
		args.push (err, results, fields) =>
			if err then callback.call @app, err, null, null
			else
				if results.length is 0 then callback.call @app, err, false, results
				else callback.call @app, err, true, results
			null

		if cdata? # Inject cdata to first parameter (forwarding cdata to next function)
			cdata.param = args[0]
			args[0] = cdata

		@queryWhere.apply this, args


	# <!-- ============================================================================================ -->
	# # Private Functions <hr/><br/>
	# <!-- ============================================================================================ -->

	# ## cachedQuery
	# 
	# 	(cdata, params...)
	# 	
	# Handles query caching internally. Runs on the class instance's context
	# 
	# **@param array cdata** <br/>
	# Array with cache parameters. Contains [cacheID, timeout] <br/>
	# **@param array params...** <br/>
	# Splat (array) containing the rest of the function's arguments <br/>
	# **@inner**
	# <hr/>

	cachedQuery = (cdata, params...) ->
		
		# Ignore cache if cdata is not specified
		if typeof cdata isnt 'object' or (cdata.cacheID is undefined and cdata.invalidate is undefined)
			@client.__query.apply @client, [cdata, params...]
			return  # Exit function
		
		{cacheID, timeout, invalidate} = cdata
		
		if invalidate?
			# Invalidate caches. Silent if cacheID does not exist
			invalidate = [invalidate] unless isArray(invalidate)
			multi = @redis.multi()
			multi.del "mysql_cache_#{cacheID}" for cacheID in invalidate
			multi.exec (err, info) =>
				if err
					@app.log err
					callback = params.pop()
					callback.apply? this, [err, null, null]  # Callback handles the error
				else
					@app.debug "Invalidated cacheID '#{invalidate.toString()}'"
					@client.__query.apply @client, params
					return  # Exit function

		else
			# Store or Retrieve cache
			@redis.get "mysql_cache_#{cacheID}", (err, cache) =>
				if err
					@app.log err
					callback = params.pop()
					callback.apply? this, [err, null, null]  # Callback handles the error
				else
					
					if cache?
						
						# Cache available -> Use
						
						@app.debug "Using cache for cacheID '#{cacheID}'"
						cache = JSON.parse cache
						origCallback = params.pop()
						origCallback.apply? @, cache
						
					else
						
						# Cache not available -> Store
						
						origCallback = params.pop()  # Get the original callback (we can safely assume the last param is the callback)
						params.push (err, results, fields) =>  # Append cache callback to params array
							if err
								@app.log err
								callback = params.pop()
								callback.apply? this, [err, null, null]  # Callback handles the error
							else
								cacheKey = "mysql_cache_#{cacheID}"
								timeout = @maxCacheTimeout unless timeout > 0
								queryResults = [err, results, fields]
								multi = @redis.multi()
								multi.set cacheKey, JSON.stringify queryResults
								multi.expire cacheKey, timeout
								multi.exec (err, replies) =>
									if err
										@app.log err
										callback = params.pop()
										callback.apply? this, [err, null, null]  # Callback handles the error
									else
										@app.debug "Stored new cache for cacheID '#{cacheID}'. Expires #{(new Date(Date.now() + timeout*1000)).toString()}"
										origCallback.apply @, queryResults # Run callback with data
							null
								
						@client.__query.apply @client, params  # Call @query with cache callback (using @client as context)
		null

module.exports = CDatabase

# <br/>