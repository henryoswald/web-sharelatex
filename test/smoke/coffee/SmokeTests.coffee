child   = require "child_process"
fs = require "fs"
assert = require("assert")
chai = require("chai")
chai.should() unless Object.prototype.should?
expect = chai.expect
Settings = require "settings-sharelatex"
ownPort = Settings.internal?.web?.port or Settings.port or 3000
port = Settings.web?.web_router_port or ownPort # send requests to web router if this is the api process
cookeFilePath = "/tmp/smoke-test-cookie-#{ownPort}-to-#{port}.txt"
buildUrl = (path) -> " -b #{cookeFilePath} --resolve 'smoke#{Settings.cookieDomain}:#{port}:127.0.0.1' http://smoke#{Settings.cookieDomain}:#{port}/#{path}?setLng=en"
logger = require "logger-sharelatex"

# Change cookie to be non secure so curl will send it
convertCookieFile = (callback) ->
	fs = require("fs")
	fs.readFile cookeFilePath, "utf8", (err, data) ->
		return callback(err) if err
		firstTrue = data.indexOf("TRUE")
		secondTrue = data.indexOf("TRUE", firstTrue+4)
		result = data.slice(0, secondTrue)+"FALSE"+data.slice(secondTrue+4)
		fs.writeFile cookeFilePath, result, "utf8", (err) ->
			return callback(err) if err
			callback()

describe "Opening", ->

	before (done) ->
		logger.log "smoke test: setup"
		require("../../../app/js/Features/Security/LoginRateLimiter.js").recordSuccessfulLogin Settings.smokeTest.user, (err)->
			if err?
				logger.err err:err, "smoke test: error recoring successful login"
				return done(err)
			logger.log "smoke test: clearing rate limit "
			require("../../../app/js/infrastructure/RateLimiter.js").clearRateLimit "open-project", "#{Settings.smokeTest.projectId}:#{Settings.smokeTest.userId}", ->
				logger.log "smoke test: hitting /register"
				command =  """
					curl -H  "X-Forwarded-Proto: https" -c #{cookeFilePath} #{buildUrl('register')}
				"""
				child.exec command, (err, stdout, stderr)->
					if err? then done(err)
					csrfMatches = stdout.match("<input name=\"_csrf\" type=\"hidden\" value=\"(.*?)\">")
					if !csrfMatches?
						logger.err stdout:stdout, "smoke test: does not have csrf token"
						return done("smoke test: does not have csrf token")
					csrf = csrfMatches[1]
					logger.log "smoke test: converting cookie file 1"
					convertCookieFile (err) ->
						return done(err) if err?
						logger.log "smoke test: hitting /register with csrf"
						command = """
							curl -c #{cookeFilePath} -H "Content-Type: application/json" -H "X-Forwarded-Proto: https" -d '{"_csrf":"#{csrf}", "email":"#{Settings.smokeTest.user}", "password":"#{Settings.smokeTest.password}"}' #{buildUrl('register')}
						"""
						child.exec command, (err) ->
							return done(err) if err?
							logger.log "smoke test: finishing setup"
							convertCookieFile done

	after (done)->
		logger.log "smoke test: cleaning up"
		command =  """
			curl -H  "X-Forwarded-Proto: https" -c #{cookeFilePath} #{buildUrl('logout')}
		"""
		child.exec command, (err, stdout, stderr)->
			if err?
				return done(err)
			fs.unlink cookeFilePath, done

	it "a project", (done) ->
		logger.log "smoke test: Checking can load a project"
		@timeout(4000)
		command =  """
			curl -H "X-Forwarded-Proto: https" -v #{buildUrl("project/#{Settings.smokeTest.projectId}")}
		"""
		child.exec command, (error, stdout, stderr)->
			expect(error, "smoke test: error in getting project").to.not.exist
		
			statusCodeMatch = !!stderr.match("200 OK")
			expect(statusCodeMatch, "smoke test: response code is not 200 getting project").to.equal true
			
			# Check that the project id is present in the javascript that loads up the project
			match = !!stdout.match("window.project_id = \"#{Settings.smokeTest.projectId}\"")
			expect(match, "smoke test: project page html does not have project_id").to.equal true
			done()


	it "the project list", (done) ->
		logger.log "smoke test: Checking can load project list"
		@timeout(4000)
		command =  """
			curl -H "X-Forwarded-Proto: https" -v #{buildUrl("project")}
		"""
		child.exec command, (error, stdout, stderr)->
		
			expect(error, "smoke test: error returned in getting project list").to.not.exist
			expect(!!stderr.match("200 OK"), "smoke test: response code is not 200 getting project list").to.equal true
			expect(!!stdout.match("<title>Your Projects - ShareLaTeX, Online LaTeX Editor</title>"), "smoke test: body does not have correct title").to.equal true
			expect(!!stdout.match("ProjectPageController"), "smoke test: body does not have correct angular controller").to.equal true
			done()
	

