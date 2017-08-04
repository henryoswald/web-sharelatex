should = require('chai').should()
spies = require('chai-spies')
chai = require('chai').use(spies)
sinon = require("sinon")
SandboxedModule = require('sandboxed-module')
assert = require('chai').assert
path = require 'path'
_ = require 'underscore'
modulePath = path.join __dirname, '../../../../app/js/Features/DocumentUpdater/DocumentUpdaterHandler'

describe 'DocumentUpdaterHandler', ->
	beforeEach ->
		@project_id = "project-id-923"
		@doc_id = "doc-id-394"
		@lines = ["one", "two", "three"]
		@version = 42
		@user_id = "mock-user-id-123"
		@project =
			_id: @project_id

		@request = {}
		@projectEntityHandler = {}
		@settings = 
			apis : documentupdater: url : "http://something.com"
		@handler = SandboxedModule.require modulePath, requires:
			'request': defaults:=> return @request
			'settings-sharelatex':@settings
			'logger-sharelatex':{log:(->), error:(->)}
			'../Project/ProjectEntityHandler':@projectEntityHandler
			"../../models/Project": Project: @Project={}
			'../../Features/Project/ProjectLocator':{}
			"metrics-sharelatex": 
				Timer:->
					done:->

	describe 'flushProjectToMongo', ->
		beforeEach ->
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, {statusCode: 204}, "")
				@handler.flushProjectToMongo @project_id, @callback

			it 'should flush the document from the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/flush"
				@request.post.calledWith(url).should.equal true

			it "should call the callback with no error", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.flushProjectToMongo @project_id, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.flushProjectToMongo @project_id, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe 'flushProjectToMongoAndDelete', ->
		beforeEach ->
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, {statusCode: 204}, "")
				@handler.flushProjectToMongoAndDelete @project_id, @callback

			it 'should delete the project from the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}"
				@request.del.calledWith(url).should.equal true

			it "should call the callback with no error", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.flushProjectToMongoAndDelete @project_id, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.flushProjectToMongoAndDelete @project_id, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe 'flushDocToMongo', ->
		beforeEach ->
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, {statusCode: 204}, "")
				@handler.flushDocToMongo @project_id, @doc_id, @callback

			it 'should flush the document from the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}/flush"
				@request.post.calledWith(url).should.equal true

			it "should call the callback with no error", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.flushDocToMongo @project_id, @doc_id, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.flushDocToMongo @project_id, @doc_id, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe "deleteDoc", ->
		beforeEach ->
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, {statusCode: 204}, "")
				@handler.deleteDoc @project_id, @doc_id, @callback

			it 'should delete the document from the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}"
				@request.del.calledWith(url).should.equal true

			it "should call the callback with no error", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.deleteDoc @project_id, @doc_id, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.deleteDoc @project_id, @doc_id, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe "setDocument", ->
		beforeEach ->
			@callback = sinon.stub()
			@source = "dropbox"

		describe "successfully", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, {statusCode: 204}, "")
				@handler.setDocument @project_id, @doc_id, @user_id, @lines, @source, @callback

			it 'should set the document in the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}"
				@request.post
					.calledWith({
						url: url
						json:
							lines: @lines
							source: @source
							user_id: @user_id
					})
					.should.equal true

			it "should call the callback with no error", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.setDocument @project_id, @doc_id, @user_id, @lines, @source, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.setDocument @project_id, @doc_id, @user_id, @lines, @source, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe "getDocument", ->
		beforeEach ->
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@body = JSON.stringify
					lines: @lines
					version: @version
					ops: @ops = ["mock-op-1", "mock-op-2"]
					ranges: @ranges = {"mock":"ranges"}
				@fromVersion = 2
				@request.get = sinon.stub().callsArgWith(1, null, {statusCode: 200}, @body)
				@handler.getDocument @project_id, @doc_id, @fromVersion, @callback

			it 'should get the document from the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}?fromVersion=#{@fromVersion}"
				@request.get.calledWith(url).should.equal true

			it "should call the callback with the lines and version", ->
				@callback.calledWith(null, @lines, @version, @ranges, @ops).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.get = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.getDocument @project_id, @doc_id, @fromVersion, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.get = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.getDocument @project_id, @doc_id, @fromVersion, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe "acceptChanges", ->
		beforeEach ->
			@change_id = "mock-change-id-1"
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, {statusCode: 200}, @body)
				@handler.acceptChanges @project_id, @doc_id, [ @change_id ], @callback

			it 'should accept the change in the document updater', ->
				req =
					url: "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}/change/accept"
					json:
						change_ids: [ @change_id ]
				@request.post.calledWith(req).should.equal true

			it "should call the callback", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.acceptChanges @project_id, @doc_id, [ @change_id ], @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.acceptChanges @project_id, @doc_id, [ @change_id ], @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true

	describe "deleteThread", ->
		beforeEach ->
			@thread_id = "mock-thread-id-1"
			@callback = sinon.stub()

		describe "successfully", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, {statusCode: 200}, @body)
				@handler.deleteThread @project_id, @doc_id, @thread_id, @callback

			it 'should delete the thread in the document updater', ->
				url = "#{@settings.apis.documentupdater.url}/project/#{@project_id}/doc/#{@doc_id}/comment/#{@thread_id}"
				@request.del.calledWith(url).should.equal true

			it "should call the callback", ->
				@callback.calledWith(null).should.equal true

		describe "when the document updater API returns an error", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, @error = new Error("something went wrong"), null, null)
				@handler.deleteThread @project_id, @doc_id, @thread_id, @callback

			it "should return an error to the callback", ->
				@callback.calledWith(@error).should.equal true

		describe "when the document updater returns a failure error code", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, { statusCode: 500 }, "")
				@handler.deleteThread @project_id, @doc_id, @thread_id, @callback

			it "should return the callback with an error", ->
				@callback
					.calledWith(new Error("doc updater returned failure status code: 500"))
					.should.equal true