should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
sinon = require('sinon')
modulePath = path.join __dirname, "../../../../app/js/Features/PasswordReset/PasswordResetHandler"
expect = require("chai").expect

describe "PasswordResetHandler", ->

	beforeEach ->

		@settings = 
			siteUrl: "www.sharelatex.com"
		@OneTimeTokenHandler =
			getNewToken:sinon.stub()
			getValueFromTokenAndExpire:sinon.stub()
		@UserGetter =
			getUser:sinon.stub()
		@EmailHandler = 
			sendEmail:sinon.stub()
		@AuthenticationManager =
			setUserPassword:sinon.stub()
		@PasswordResetHandler = SandboxedModule.require modulePath, requires:
			"../User/UserGetter": @UserGetter
			"../Security/OneTimeTokenHandler": @OneTimeTokenHandler
			"../Email/EmailHandler":@EmailHandler
			"../Authentication/AuthenticationManager":@AuthenticationManager
			"settings-sharelatex": @settings
			"logger-sharelatex": 
				log:->
				err:->
		@token = "12312321i"
		@user_id = "user_id_here"
		@user = 
			email :"bob@bob.com"
		@password = "my great secret password"


	describe "generateAndEmailResetToken", ->

		it "should check the user exists", (done)->
			@UserGetter.getUser.callsArgWith(1)
			@OneTimeTokenHandler.getNewToken.callsArgWith(1)
			@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
				exists.should.equal false
				done()


		it "should send the email with the token", (done)->

			@UserGetter.getUser.callsArgWith(1, null, @user)
			@OneTimeTokenHandler.getNewToken.callsArgWith(1, null, @token)
			@EmailHandler.sendEmail.callsArgWith(2)
			@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
				@EmailHandler.sendEmail.called.should.equal true
				exists.should.equal true
				args = @EmailHandler.sendEmail.args[0]
				args[0].should.equal "passwordResetRequested"
				args[1].setNewPasswordUrl.should.equal "#{@settings.siteUrl}/user/password/set?passwordResetToken=#{@token}&email=#{encodeURIComponent(@user.email)}"
				done()

		it "should return exists = false for a holdingAccount", (done) ->
			@user.holdingAccount = true
			@UserGetter.getUser.callsArgWith(1, null, @user)
			@OneTimeTokenHandler.getNewToken.callsArgWith(1)
			@PasswordResetHandler.generateAndEmailResetToken @user.email, (err, exists)=>
				exists.should.equal false
				done()

	describe "setNewUserPassword", ->

		it "should return false if no user id can be found", (done)->
			@OneTimeTokenHandler.getValueFromTokenAndExpire.callsArgWith(1)
			@PasswordResetHandler.setNewUserPassword @token, @password, (err, found) =>
				found.should.equal false
				@AuthenticationManager.setUserPassword.called.should.equal false
				done()		

		it "should set the user password", (done)->
			@OneTimeTokenHandler.getValueFromTokenAndExpire.callsArgWith(1, null, @user_id)
			@AuthenticationManager.setUserPassword.callsArgWith(2)
			@PasswordResetHandler.setNewUserPassword @token, @password, (err, found, user_id) =>
				found.should.equal true
				user_id.should.equal @user_id
				@AuthenticationManager.setUserPassword.calledWith(@user_id, @password).should.equal true
				done()			

