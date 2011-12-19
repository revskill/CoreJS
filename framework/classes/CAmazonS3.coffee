
# # CAmazonS3
# 
# Amazon S3 Class. Available as **app.aws**
#
# **@uses**
#
# - [noxmox](https://github.com/nephics/noxmox)
#
# <hr/><br/>
	
class CAmazonS3
	
	defaultBucket: null
	buckets: {}
	bucketUrls: {}
	defaultServer: 's3.amazonaws.com'
	publicAcl: 'public-read'
	
	# ## constructor
	# 
	# 	(@app)
	# **@param app** <br/>
	#  Application instance <br/>
	# <hr/>
	
	constructor: (app) -> 
		Object.defineProperty @, 'app', {value: app, writable: true, enumerable: false, configurable: true}
		@className = @constructor.name


	# ## createClient
	# 
	# 	(credentials)
	# 
	# Creates an s3 Client (production)
	# 
	# **@param credentials object** <br/>
	#  containing the credentials to use. Keys:  key/secret/bucket <br/>
	# **@returns** <br/>
	#  AmazonS3 production client
	# <hr/>
	
	createClient: (credentials) ->
		framework.modules.noxmox.nox.createClient credentials # Credentials: key/secret/bucket
	
	
	# ## createSimClient
	# 
	# 	(credentials)
	# 
	# Creates an s3 Client (simulation)
	# 
	# **@param credentials object** <br/>
	#  containing the credentials to use. Keys:  key/secret/bucket <br/>
	# **@returns** <br/>
	#  AmazonS3 simulation client
	# <hr/>
		
	createSimClient: (credentials) ->
		framework.modules.noxmox.mox.createClient credentials # Credentials: key/secret/bucket


	# ## setBucketCredentials
	# 
	# 	(bucket, credentials)
	# 
	# Sets credentials for a bucket (production)
	# 
	# **@param bucket** Bucket name <br/>
	# **@param credentials** <br/>
	#  object containing the credentials to use. Keys:  key/secret/bucket
	# <hr/>

	setBucketCredentials: (bucket, credentials) ->
		unless credentials? then credentials = bucket; bucket = @defaultBucket
		credentials.bucket = bucket
		protocol = if credentials.https? then 'https://' else 'http://'
		@bucketUrls[bucket] = if credentials.server? then "#{protocol}#{credentials.server}/#{bucket}/" else "#{protocol}#{@defaultServer}/#{bucket}/"
		@buckets[bucket] = @createClient credentials
	

	# ## setSimBucketCredentials
	# 
	# 	(bucket, credentials)
	# 
	# Sets credentials for a bucket (simulation)
	# 
	# **@param bucket** <br/>
	#  Bucket name <br/>
	# **@param credentials** <br/>
	#  object containing the credentials to use. Keys:  key/secret/bucket
	# <hr/>
	
	setSimBucketCredentials: (bucket, credentials) ->
		unless credentials? then credentials = bucket; bucket = @defaultBucket
		credentials.bucket = bucket
		credentials.prefix = @app.fullPath '/private/tmp/s3'
		protocol = if credentials.https? then 'https://' else 'http://'
		@bucketUrls[bucket] = if credentials.server? then "#{protocol}#{credentials.server}/#{bucket}/" else "#{protocol}#{@defaultServer}/#{bucket}/"
		@buckets[bucket] = @createSimClient credentials
	
	
	# ## upload
	# 
	# 	(bucket, files, headers, callback)  [err, responses]
	# 
	# Uploads files to s3
	# 
	# The uploaded files will be private
	# 
	# **@param bucket** <br/>
	#  Bucket name <br/>
	# **@param object files** <br/>
	#  Files to upload in relative:remote pairs of paths <br/>
	# **@param object headers** <br/>
	#  Headers to send to s3 <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>
	
	upload: (bucket, files, headers, callback) ->
		
		# Process Arguments
		
		if typeof bucket isnt 'string' and typeof bucket is 'object'
			callback = headers
			headers = files
			files = bucket
			bucket = @defaultBucket
		
		if not callback? and typeof headers is 'function'
			callback = headers
			headers = {}
	
		args = 
			error: null
			counter: 0
			responses: {}
			bucket: bucket
			files: files
			fileSources: _.keys files
			headers: headers
			callback: callback
			
		doUpload.call this, args
		

	# ## publicUpload
	# 
	# 	(bucket, files, callback)  [err, responses]
	# 
	# Uploads files to s3
	# 
	# The uploaded files will be public
	# 
	# **@param bucket** <br/>
	#  Bucket name <br/>
	# **@param object files** <br/>
	#  Files to upload in relative:remote pairs of paths <br/>
	# **@param function callback** <br/>
	#  Callback to call upon completion
	# <hr/>
	
	publicUpload: (bucket, files, callback) ->
		if typeof bucket isnt 'string'
			callback = files
			files = bucket
			bucket = @defaultBucket
		
		@upload bucket, files, {'x-amz-acl': @publicAcl}, callback
		
	
	# ## delete
	# 
	# 	(bucket, files, callback)  [err, responses]
	# 
	# Delete files from s3
	# 
	# **@param bucket** <br/>
	#  Bucket name <br/>
	# **@param array** <br/>
	#  files Array of files to delete from s3 <br/>
	# **@param function** <br/>
	#  callback Callback to call upon completion
	# <hr/>
		
	delete: (bucket, files, callback) ->
		unless typeof bucket is 'string'
			callback = files
			files = bucket
			bucket = @defaultBucket
			
		args =
			counter: 0
			error: null
			responses: {}
			bucket: bucket
			files: files
			callback: callback
		
		doDelete.call this, args


	# ## getBucketUrl
	# 
	# 	(bucket, file)
	# 
	# Returns the URL of a file in a bucket
	# 
	# **@param bucket** <br/>
	#  Bucket name <br/>
	# **@param file** <br/>
	#  path to file in bucket <br/>
	# **@returns** <br/>
	#  URL of file in bucket
	# <hr/>

	getBucketUrl: (bucket, file) ->
		@bucketUrls[bucket] + file.replace(@app.regex.startsWithSlash, '')

		
	# # Private Functions
	# <hr/><br/>
	
	
	# ## doUpload
	# 
	# 	(args)
	# 
	# Internal upload function. Used in the @upload method
	# 
	# **@param args** <br/>
	#  arguments for the loop <br/>
	# **@inner**
	# <hr/>
	
	doUpload = (args) ->
		if args.counter is args.fileSources.length
			{callback, responses, error} = args
			callback.call this, error, responses
		else
			self = @
			src = args.fileSources[args.counter] # source file
			dest = args.files[src] # destination file
			file = @app.fullPath src unless @app.regex.startsWithSlash.test file
			@app.modules.fs.readFile file, (err, data) ->
				if err
					args.responses[src] = err # reading error for local file
					args.error = true
					args.counter++
					doUpload.call self, args
				else
					{bucket, headers} = args
					headers = _.extend headers,
						'Content-Length': data.length
						'Content-Type': self.app.modules.mime.lookup file
					awsRequest = self.buckets[bucket].put dest, headers
					awsRequest.on 'continue', -> awsRequest.end data
					awsRequest.on 'response', (awsResponse) ->
						awsResponse.on 'end', ->
							args.responses[dest] = ( if awsResponse.statusCode is 200 then self.getBucketUrl(args.bucket, dest) else awsResponse.statusCode )
							args.error = true unless typeof args.responses[dest] is 'string'
							args.counter++
							doUpload.call self, args
				null
			null


	# ## doDelete
	# 
	# 	(args)
	# 
	# Internal delete function. Used in the @delete method
	# 
	# **@param args**  <br/>
	#  arguments for the loop <br/>
	# **@inner**
	# <hr/>

	doDelete = (args) ->
		if args.counter is args.files.length
			{callback, responses, error} = args
			callback.call this, error, responses
		else
			self = @
			file = args.files[args.counter]
			awsRequest = @buckets[args.bucket].del file
			awsRequest.end()
			awsRequest.on 'response', (awsResponse) ->
				awsResponse.on 'end', ->
					args.responses[file] = if awsResponse.statusCode is 204 then true else awsResponse.statusCode
					args.error = true unless args.responses[file] is true
					args.counter++
					doDelete.call self, args


module.exports = CAmazonS3

# <br/>