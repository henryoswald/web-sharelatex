RateLimiter = require "../../infrastructure/RateLimiter"
logger = require "logger-sharelatex"
AuthenticationController = require('../Authentication/AuthenticationController')

module.exports = RateLimiterMiddlewear =
	###
	Do not allow more than opts.maxRequests from a single client in
	opts.timeInterval. Pass an array of opts.params to segment this based on
	parameters in the request URL, e.g.:

	    app.get "/project/:project_id", RateLimiterMiddlewear.rateLimit(endpointName: "open-editor", params: ["project_id"])

	will rate limit each project_id separately.

	Unique clients are identified by user_id if logged in, and IP address if not.
	###
	rateLimit: (opts) ->
		return (req, res, next) ->
			user_id = AuthenticationController.getLoggedInUserId(req) || req.ip
			params = (opts.params or []).map (p) -> req.params[p]
			params.push user_id
			subjectName = params.join(":")
			if opts.ipOnly
				subjectName = req.ip
			if !opts.endpointName?
				throw new Error("no endpointName provided")
			options = {
				endpointName: opts.endpointName
				timeInterval: opts.timeInterval or 60
				subjectName:  subjectName
				throttle:     opts.maxRequests or 6
			}
			RateLimiter.addCount options, (error, canContinue)->
				return next(error) if error?
				if canContinue
					next()
				else
					logger.warn options, "rate limit exceeded"
					res.status(429) # Too many requests
					res.write("Rate limit reached, please try again later")
					res.end()
