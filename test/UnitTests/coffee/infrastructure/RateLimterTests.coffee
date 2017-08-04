assert = require("chai").assert
sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/infrastructure/RateLimiter.js"
SandboxedModule = require('sandboxed-module')

describe "RateLimiter", ->

	beforeEach ->
		@settings = 
			redis:
				web:
					port:"1234"
					host:"somewhere"
					password: "password"
		@rclient =
			incr: sinon.stub()
			get: sinon.stub()
			expire: sinon.stub()
			exec: sinon.stub()
		@rclient.multi = sinon.stub().returns(@rclient)
		@RedisWrapper =
			client: sinon.stub().returns(@rclient)

		@limiterFn = sinon.stub()
		@RollingRateLimiter = (opts) =>
			return @limiterFn

		@limiter = SandboxedModule.require modulePath, requires:
			"rolling-rate-limiter": @RollingRateLimiter
			"settings-sharelatex":@settings
			"logger-sharelatex" : @logger = {log:sinon.stub(), err:sinon.stub()}
			"./RedisWrapper": @RedisWrapper

		@endpointName = "compiles"
		@subject = "some-project-id"
		@timeInterval = 20
		@throttleLimit = 5

		@details = 
			endpointName: @endpointName
			subjectName: @subject
			throttle: @throttleLimit
			timeInterval: @timeInterval
		@key = "RateLimiter:#{@endpointName}:{#{@subject}}"




	describe 'when action is permitted', ->

		beforeEach ->
			@limiterFn = sinon.stub().callsArgWith(1, null, 0, 22)

		it 'should not produce and error', (done) ->
			@limiter.addCount {}, (err, should) ->
				expect(err).to.equal null
				done()

		it 'should callback with true', (done) ->
			@limiter.addCount {}, (err, should) ->
				expect(should).to.equal true
				done()

	describe 'when action is not permitted', ->

		beforeEach ->
			@limiterFn = sinon.stub().callsArgWith(1, null, 4000, 0)

		it 'should not produce and error', (done) ->
			@limiter.addCount {}, (err, should) ->
				expect(err).to.equal null
				done()

		it 'should callback with false', (done) ->
			@limiter.addCount {}, (err, should) ->
				expect(should).to.equal false
				done()

	describe 'when limiter produces an error', ->

		beforeEach ->
			@limiterFn = sinon.stub().callsArgWith(1, new Error('woops'))

		it 'should produce and error', (done) ->
			@limiter.addCount {}, (err, should) ->
				expect(err).to.not.equal null
				expect(err).to.be.instanceof Error
				done()
