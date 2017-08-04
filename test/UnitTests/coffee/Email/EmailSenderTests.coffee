should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
sinon = require('sinon')
modulePath = path.join __dirname, "../../../../app/js/Features/Email/EmailSender.js"
expect = require("chai").expect

describe "EmailSender", ->

	beforeEach ->

		@RateLimiter =
			addCount:sinon.stub()

		@settings =
			email:
				transport: "ses"
				parameters:
					AWSAccessKeyID: "key"
					AWSSecretKey: "secret"
				fromAddress: "bob@bob.com"
				replyToAddress: "sally@gmail.com"

		@sesClient =
			sendMail: sinon.stub()

		@ses =
			createTransport: => @sesClient


		@sender = SandboxedModule.require modulePath, requires:
			'nodemailer': @ses
			"settings-sharelatex":@settings
			'../../infrastructure/RateLimiter':@RateLimiter
			"logger-sharelatex":
				log:->
				warn:->
				err:->
			"metrics-sharelatex": inc:->



		@opts =
			to: "bob@bob.com"
			subject: "new email"
			html: "<hello></hello>"

	describe "sendEmail", ->

		it "should set the properties on the email to send", (done)->
			@sesClient.sendMail.callsArgWith(1)

			@sender.sendEmail @opts, (err) =>
				expect(err).to.not.exist
				args = @sesClient.sendMail.args[0][0]
				args.html.should.equal @opts.html
				args.to.should.equal @opts.to
				args.subject.should.equal @opts.subject
				done()

		it "should return a non-specific error", (done)->
			@sesClient.sendMail.callsArgWith(1, "error")
			@sender.sendEmail {}, (err)=>
				err.should.exist
				err.toString().should.equal 'Error: Cannot send email'
				done()


		it "should use the from address from settings", (done)->
			@sesClient.sendMail.callsArgWith(1)

			@sender.sendEmail @opts, =>
				args = @sesClient.sendMail.args[0][0]
				args.from.should.equal @settings.email.fromAddress
				done()

		it "should use the reply to address from settings", (done)->
			@sesClient.sendMail.callsArgWith(1)

			@sender.sendEmail @opts, =>
				args = @sesClient.sendMail.args[0][0]
				args.replyTo.should.equal @settings.email.replyToAddress
				done()


		it "should use the reply to address in options as an override", (done)->
			@sesClient.sendMail.callsArgWith(1)

			@opts.replyTo = "someone@else.com"
			@sender.sendEmail @opts, =>
				args = @sesClient.sendMail.args[0][0]
				args.replyTo.should.equal @opts.replyTo
				done()


		it "should not send an email when the rate limiter says no", (done)->
			@opts.sendingUser_id = "12321312321"
			@RateLimiter.addCount.callsArgWith(1, null, false)
			@sender.sendEmail @opts, =>
				@sesClient.sendMail.called.should.equal false
				done()

		it "should send the email when the rate limtier says continue",  (done)->
			@sesClient.sendMail.callsArgWith(1)
			@opts.sendingUser_id = "12321312321"
			@RateLimiter.addCount.callsArgWith(1, null, true)
			@sender.sendEmail @opts, =>
				@sesClient.sendMail.called.should.equal true
				done()

		it "should not check the rate limiter when there is no sendingUser_id", (done)->
			@sesClient.sendMail.callsArgWith(1)
			@sender.sendEmail @opts, =>
				@sesClient.sendMail.called.should.equal true
				@RateLimiter.addCount.called.should.equal false
				done()

		describe 'with plain-text email content', () ->

			beforeEach ->
				@opts.text = "hello there"

			it "should set the text property on the email to send", (done)->
				@sesClient.sendMail.callsArgWith(1)

				@sender.sendEmail @opts, =>
					args = @sesClient.sendMail.args[0][0]
					args.html.should.equal @opts.html
					args.text.should.equal @opts.text
					args.to.should.equal @opts.to
					args.subject.should.equal @opts.subject
					done()
