settings = require("settings-sharelatex")
async = require("async")
UserGetter = require("../User/UserGetter")
OneTimeTokenHandler = require("../Security/OneTimeTokenHandler")
EmailHandler = require("../Email/EmailHandler")
AuthenticationManager = require("../Authentication/AuthenticationManager")
logger = require("logger-sharelatex")

module.exports =

	generateAndEmailResetToken:(email, callback = (error, exists) ->)->
		UserGetter.getUser email:email, (err, user)->
			if err then return callback(err)
			if !user? or user.holdingAccount
				logger.err email:email, "user could not be found for password reset"
				return callback(null, false)
			OneTimeTokenHandler.getNewToken user._id, (err, token)->
				if err then return callback(err)
				emailOptions =
					to : email
					setNewPasswordUrl : "#{settings.siteUrl}/user/password/set?passwordResetToken=#{token}&email=#{encodeURIComponent(email)}"
				EmailHandler.sendEmail "passwordResetRequested", emailOptions, (error) ->
					return callback(error) if error?
					callback null, true

	setNewUserPassword: (token, password, callback = (error, found, user_id) ->)->
		OneTimeTokenHandler.getValueFromTokenAndExpire token, (err, user_id)->
			if err then return callback(err)
			if !user_id?
				return callback null, false, null
			AuthenticationManager.setUserPassword user_id, password, (err) ->
				if err then return callback(err)
				callback null, true, user_id