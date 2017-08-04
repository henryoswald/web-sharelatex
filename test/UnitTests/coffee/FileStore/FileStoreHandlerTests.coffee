assert = require("chai").assert
sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/FileStore/FileStoreHandler.js"
SandboxedModule = require('sandboxed-module')

describe "FileStoreHandler", ->
	beforeEach ->
		@fs =
			createReadStream : sinon.stub()
			lstat: sinon.stub().callsArgWith(1, null, {
				isFile:=> @isSafeOnFileSystem
				isDirectory:-> return false
			})
		@writeStream =
			my:"writeStream"
			on: (type, cb)-> 
				if type == "response"
					cb({statusCode: 200})
		@readStream = {my:"readStream", on: sinon.stub()}
		@request = sinon.stub()
		@settings = apis:{filestore:{url:"http//filestore.sharelatex.test"}}
		@handler = SandboxedModule.require modulePath, requires:
			"settings-sharelatex":@settings
			"request":@request
			"logger-sharelatex" : @logger = {log:sinon.stub(), err:sinon.stub()}
			"fs" : @fs
		@file_id = "file_id_here"
		@project_id = "1312312312"
		@fsPath = "uploads/myfile.eps"
		@handler._buildUrl = sinon.stub().returns("http://filestore.stubbedBuilder.com")

	describe "uploadFileFromDisk", ->
		beforeEach ->
			@request.returns(@writeStream)
			@isSafeOnFileSystem = true

		it "should create read stream", (done)->
			@fs.createReadStream.returns 
				pipe:->
				on: (type, cb)->
					if type == "open"
						cb()
			@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>
				@fs.createReadStream.calledWith(@fsPath).should.equal true
				done()

		it "should pipe the read stream to request", (done)->
			@request.returns(@writeStream)
			@fs.createReadStream.returns 
				on: (type, cb)-> 
					if type == "open"
						cb()
				pipe:(o)=>
					@writeStream.should.equal o
					done()
			@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>

		it "should pass the correct options to request", (done)->
			@fs.createReadStream.returns 
				pipe:->
				on: (type, cb)-> 
					if type == "open"
						cb()
			@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>
				@request.args[0][0].method.should.equal "post"
				@request.args[0][0].uri.should.equal @handler._buildUrl()
				done()

		it "builds the correct url", (done)->
			@fs.createReadStream.returns 
				pipe:->
				on: (type, cb)-> 
					if type == "open"
						cb()
			@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>
				@handler._buildUrl.calledWith(@project_id, @file_id).should.equal true
				done()

		it 'should callback with null', (done) ->
			@fs.createReadStream.returns
				pipe:->
				on: (type, cb)->
					if type == "open"
						cb()
			@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, (err) =>
				expect(err).to.not.exist
				done()

		describe "symlink", ->
			it "should not read file if it is symlink", (done)->
				@isSafeOnFileSystem = false
				@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>
					@fs.createReadStream.called.should.equal false
					done()

		describe "symlink", ->
			it "should not read file stat returns nothing", (done)->
				@fs.lstat = sinon.stub().callsArgWith(1, null, null)
				@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, =>
					@fs.createReadStream.called.should.equal false
					done()

		describe "when upload fails", ->
			beforeEach ->
				@writeStream.on = (type, cb) ->
					if type == "response"
						cb({statusCode: 500})

			it 'should callback with an error', (done) ->
				@fs.createReadStream.returns
					pipe:->
					on: (type, cb)->
						if type == "open"
							cb()
				@handler.uploadFileFromDisk @project_id, @file_id, @fsPath, (err) =>
					expect(err).to.exist
					expect(err).to.be.instanceof Error
					done()

	describe "deleteFile", ->

		it "should send a delete request to filestore api", (done)->
			@request.callsArgWith(1, null)
			@handler.deleteFile @project_id, @file_id, (err)=>
				assert.equal err, undefined
				@request.args[0][0].method.should.equal "delete"
				@request.args[0][0].uri.should.equal @handler._buildUrl()
				done()

		it "should return the error if there is one", (done)->
			error = "my error"
			@request.callsArgWith(1, error)
			@handler.deleteFile @project_id, @file_id, (err)=>
				assert.equal err, error
				done()

		it "builds the correct url", (done)->
			@request.callsArgWith(1, null)
			@handler.deleteFile @project_id, @file_id, (err)=>
				@handler._buildUrl.calledWith(@project_id, @file_id).should.equal true
				done()

	describe "getFileStream", ->
		beforeEach ->
			@query = {}
			@request.returns(@readStream)

		it "should get the stream with the correct params", (done)->
			@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
				@request.args[0][0].method.should.equal "get"
				@request.args[0][0].uri.should.equal @handler._buildUrl()
				done()

		it "should get stream from request", (done)->
			@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
				stream.should.equal @readStream
				done()

		it "builds the correct url", (done)->
			@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
				@handler._buildUrl.calledWith(@project_id, @file_id).should.equal true
				done()

		it "should add an error handler", (done) ->
			@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
				stream.on.calledWith("error").should.equal true
				done()

		describe 'when range is specified in query', ->

			beforeEach ->
				@query = {'range': '0-10'}

			it 'should add a range header', (done) ->
				@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
					@request.callCount.should.equal 1
					headers = @request.firstCall.args[0].headers
					expect(headers).to.have.keys('range')
					expect(headers['range']).to.equal 'bytes=0-10'
					done()

			describe 'when range is invalid', ->

				['0-', '-100', 'one-two', 'nonsense'].forEach (r) =>

					beforeEach ->
						@query = {'range': "#{r}"}

					it "should not add a range header for '#{r}'", (done) ->
						@handler.getFileStream @project_id, @file_id, @query, (err, stream)=>
							@request.callCount.should.equal 1
							headers = @request.firstCall.args[0].headers
							expect(headers).to.not.have.keys('range')
							done()

	describe "copyFile", ->

		beforeEach ->
			@newProject_id = "new project"
			@newFile_id = "new file id"

		it "should post json", (done)->
			@request.callsArgWith(1, null)

			@handler.copyFile @project_id, @file_id, @newProject_id, @newFile_id, =>
				@request.args[0][0].method.should.equal "put"
				@request.args[0][0].uri.should.equal @handler._buildUrl()
				@request.args[0][0].json.source.project_id.should.equal @project_id
				@request.args[0][0].json.source.file_id.should.equal @file_id
				done()

		it "builds the correct url", (done)->
			@request.callsArgWith(1, null)
			@handler.copyFile @project_id, @file_id, @newProject_id, @newFile_id, =>
				@handler._buildUrl.calledWith(@newProject_id, @newFile_id).should.equal true
				done()


		it "should return the err", (done)->
			error = "errrror"
			@request.callsArgWith(1, error)
			@handler.copyFile @project_id, @file_id, @newProject_id, @newFile_id, (err)=>
				err.should.equal error
				done()
