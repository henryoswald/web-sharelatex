sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/Compile/ClsiManager.js"
SandboxedModule = require('sandboxed-module')

describe "ClsiManager", ->
	beforeEach ->
		@jar = {cookie:"stuff"}
		@ClsiCookieManager = 
			getCookieJar: sinon.stub().callsArgWith(1, null, @jar)
			setServerId: sinon.stub().callsArgWith(2)
			_getServerId:sinon.stub()
		@ClsiFormatChecker =
			checkRecoursesForProblems:sinon.stub().callsArgWith(1)
		@ClsiManager = SandboxedModule.require modulePath, requires:
			"settings-sharelatex": @settings =
				apis:
					filestore:
						url: "filestore.example.com"
						secret: "secret"
					clsi:
						url: "http://clsi.example.com"
					clsi_priority:
						url: "https://clsipremium.example.com"
			"../../models/Project": Project: @Project = {}
			"../Project/ProjectEntityHandler": @ProjectEntityHandler = {}
			"./ClsiCookieManager": @ClsiCookieManager
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub(), warn: sinon.stub() }
			"request": @request = sinon.stub()
			"./ClsiFormatChecker": @ClsiFormatChecker
		@project_id = "project-id"
		@user_id = "user-id"
		@callback = sinon.stub()

	describe "sendRequest", ->
		beforeEach ->
			@ClsiManager._buildRequest = sinon.stub().callsArgWith(2, null, @request = "mock-request")
			@ClsiCookieManager._getServerId.callsArgWith(1, null, "clsi3")

		describe "with a successful compile", ->
			beforeEach ->
				@ClsiManager._postToClsi = sinon.stub().callsArgWith(4, null, {
					compile:
						status: @status = "success"
						outputFiles: [{
							url: "#{@settings.apis.clsi.url}/project/#{@project_id}/user/#{@user_id}/build/1234/output/output.pdf"
							path: "output.pdf"
							type: "pdf"
							build: 1234
						},{
							url: "#{@settings.apis.clsi.url}/project/#{@project_id}/user/#{@user_id}/build/1234/output/output.log"
							path: "output.log"
							type: "log"
							build: 1234
						}]
				})
				@ClsiManager.sendRequest @project_id, @user_id, {compileGroup:"standard"}, @callback

			it "should build the request", ->
				@ClsiManager._buildRequest
					.calledWith(@project_id)
					.should.equal true

			it "should send the request to the CLSI", ->
				@ClsiManager._postToClsi
					.calledWith(@project_id, @user_id, @request, "standard")
					.should.equal true

			it "should call the callback with the status and output files", ->
				outputFiles = [{
					url: "/project/#{@project_id}/user/#{@user_id}/build/1234/output/output.pdf"
					path: "output.pdf"
					type: "pdf"
					build: 1234
				},{
					url: "/project/#{@project_id}/user/#{@user_id}/build/1234/output/output.log"
					path: "output.log"
					type: "log"
					build: 1234
				}]
				@callback.calledWith(null, @status, outputFiles).should.equal true

		describe "with a failed compile", ->
			beforeEach ->
				@ClsiManager._postToClsi = sinon.stub().callsArgWith(4, null, {
					compile:
						status: @status = "failure"
				})
				@ClsiManager.sendRequest @project_id, @user_id, {}, @callback
			
			it "should call the callback with a failure statue", ->
				@callback.calledWith(null, @status).should.equal true

	describe "deleteAuxFiles", ->
		beforeEach ->
			@ClsiManager._makeRequest = sinon.stub().callsArg(2)
			
		describe "with the standard compileGroup", ->
			beforeEach ->
				@ClsiManager.deleteAuxFiles @project_id, @user_id, {compileGroup: "standard"}, @callback

			it "should call the delete method in the standard CLSI", ->
				@ClsiManager._makeRequest
					.calledWith(@project_id, { method:"DELETE", url:"#{@settings.apis.clsi.url}/project/#{@project_id}/user/#{@user_id}"})
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true
				

	describe "_buildRequest", ->
		beforeEach ->
			@project =
				_id: @project_id
				compiler: @compiler = "latex"
				rootDoc_id: "mock-doc-id-1"
				imageName: @image = "mock-image-name"

			@docs = {
				"/main.tex": @doc_1 = {
					name: "main.tex"
					_id: "mock-doc-id-1"
					lines: ["Hello", "world"]
				},
				"/chapters/chapter1.tex": @doc_2 = {
					name: "chapter1.tex"
					_id: "mock-doc-id-2"
					lines: [
						"Chapter 1"
					]
				}
			}

			@files = {
				"/images/image.png": @file_1 = {
					name: "image.png"
					_id:  "mock-file-id-1"
					created: new Date()
				}
			}

			@Project.findById = sinon.stub().callsArgWith(2, null, @project)
			@ProjectEntityHandler.getAllDocs = sinon.stub().callsArgWith(1, null, @docs)
			@ProjectEntityHandler.getAllFiles = sinon.stub().callsArgWith(1, null, @files)

		describe "with a valid project", ->
			beforeEach (done) ->
				@ClsiManager._buildRequest @project_id, {timeout:100}, (error, request) =>
					@request = request
					done()

			it "should get the project with the required fields", ->
				@Project.findById
					.calledWith(@project_id, {compiler:1, rootDoc_id: 1, imageName: 1})
					.should.equal true

			it "should get all the docs", ->
				@ProjectEntityHandler.getAllDocs
					.calledWith(@project_id)
					.should.equal true

			it "should get all the files", ->
				@ProjectEntityHandler.getAllFiles
					.calledWith(@project_id)
					.should.equal true

			it "should build up the CLSI request", ->
				expect(@request).to.deep.equal(
					compile:
						options:
							compiler: @compiler
							timeout : 100
							imageName: @image
							draft: false
							check: undefined
						rootResourcePath: "main.tex"
						resources: [{
							path:    "main.tex"
							content: @doc_1.lines.join("\n")
						}, {
							path:    "chapters/chapter1.tex"
							content: @doc_2.lines.join("\n")
						}, {
							path: "images/image.png"
							url:  "#{@settings.apis.filestore.url}/project/#{@project_id}/file/#{@file_1._id}"
							modified: @file_1.created.getTime()
						}]
				)


		describe "when root doc override is valid", ->
			beforeEach (done) ->
				@ClsiManager._buildRequest @project_id, {rootDoc_id:"mock-doc-id-2"}, (error, request) =>
					@request = request
					done()

			it "should change root path", ->
				@request.compile.rootResourcePath.should.equal "chapters/chapter1.tex"


		describe "when root doc override is invalid", ->
			beforeEach (done) ->
				@ClsiManager._buildRequest @project_id, {rootDoc_id:"invalid-id"}, (error, request) =>
					@request = request
					done()

			it "should fallback to default root doc", ->
				@request.compile.rootResourcePath.should.equal "main.tex"



		describe "when the project has an invalid compiler", ->
			beforeEach (done) ->
				@project.compiler = "context"
				@ClsiManager._buildRequest @project, null, (error, request) =>
					@request = request
					done()

			it "should set the compiler to pdflatex", ->
				@request.compile.options.compiler.should.equal "pdflatex"

		describe "when there is no valid root document", ->
			beforeEach (done) ->
				@project.rootDoc_id = "not-valid"
				@ClsiManager._buildRequest @project, null, (@error, @request) =>
					done()

			it "should set to main.tex", ->
				@request.compile.rootResourcePath.should.equal "main.tex"
		
		describe "with the draft option", ->
			it "should add the draft option into the request", (done) ->
				@ClsiManager._buildRequest @project_id, {timeout:100, draft: true}, (error, request) =>
					request.compile.options.draft.should.equal true
					done()


	describe '_postToClsi', ->
		beforeEach ->
			@req = { mock: "req" }

		describe "successfully", ->
			beforeEach ->
				@ClsiManager._makeRequest = sinon.stub().callsArgWith(2, null, {statusCode: 204}, @body = { mock: "foo" })
				@ClsiManager._postToClsi @project_id, @user_id, @req, "standard", @callback

			it 'should send the request to the CLSI', ->
				url = "#{@settings.apis.clsi.url}/project/#{@project_id}/user/#{@user_id}/compile"
				@ClsiManager._makeRequest.calledWith(@project_id, {
					method: "POST",
					url: url
					json: @req
				}).should.equal true

			it "should call the callback with the body and no error", ->
				@callback.calledWith(null, @body).should.equal true

		describe "when the CLSI returns an error", ->
			beforeEach ->
				@ClsiManager._makeRequest = sinon.stub().callsArgWith(2, null, {statusCode: 500}, @body = { mock: "foo" })
				@ClsiManager._postToClsi @project_id, @user_id, @req, "standard", @callback

			it "should call the callback with the body and the error", ->
				@callback.calledWith(new Error("CLSI returned non-success code: 500"), @body).should.equal true


	describe "wordCount", ->
		beforeEach ->
			@ClsiManager._makeRequest = sinon.stub().callsArgWith(2, null, {statusCode: 200}, @body = { mock: "foo" })
			@ClsiManager._buildRequest = sinon.stub().callsArgWith(2, null, @req = { compile: { rootResourcePath: "rootfile.text", options: {} } })

		describe "with root file", ->
			beforeEach ->
				@ClsiManager.wordCount @project_id, @user_id, false, {}, @callback

			it "should call wordCount with root file", ->
				@ClsiManager._makeRequest
				.calledWith(@project_id, {method: "GET", url: "http://clsi.example.com/project/#{@project_id}/user/#{@user_id}/wordcount", qs: {file: "rootfile.text",image:undefined}})
				.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true
				
		describe "with param file", ->
			beforeEach ->
				@ClsiManager.wordCount @project_id, @user_id, "main.tex", {}, @callback

			it "should call wordCount with param file", ->
				@ClsiManager._makeRequest
					.calledWith(@project_id, { method: "GET", url: "http://clsi.example.com/project/#{@project_id}/user/#{@user_id}/wordcount", qs:{file:"main.tex",image:undefined}})
					.should.equal true
					
		describe "with image", ->
			beforeEach ->
				@req.compile.options.imageName = @image = "example.com/mock/image"
				@ClsiManager.wordCount @project_id, @user_id, "main.tex", {}, @callback

			it "should call wordCount with file and image", ->
				@ClsiManager._makeRequest
					.calledWith(@project_id, { method: "GET", url: "http://clsi.example.com/project/#{@project_id}/user/#{@user_id}/wordcount", qs:{file:"main.tex",image:@image}})
					.should.equal true



	describe "_makeRequest", ->

		beforeEach ->
			@response = {there:"something"}
			@request.callsArgWith(1, null, @response)
			@opts = 
				method: "SOMETHIGN"
				url: "http://a place on the web"

		it "should process a request with a cookie jar", (done)->
			@ClsiManager._makeRequest @project_id, @opts, =>
				args = @request.args[0]
				args[0].method.should.equal @opts.method
				args[0].url.should.equal @opts.url
				args[0].jar.should.equal @jar
				done()

		it "should set the cookie again on response as it might have changed", (done)->
			@ClsiManager._makeRequest @project_id, @opts, =>
				@ClsiCookieManager.setServerId.calledWith(@project_id, @response).should.equal true
				done()






