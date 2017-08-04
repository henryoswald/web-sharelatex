Stream = require('stream')
SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../../app/js/Features/ThirdPartyDataStore/UpdateMerger.js'
BufferedStream = require('bufferedstream')

describe 'UpdateMerger :', ->
	beforeEach ->
		@editorController = {}
		@updateReciver = {}
		@projectLocator = {}
		@projectEntityHandler = {}
		@fs = 
			unlink:sinon.stub().callsArgWith(1)
		@FileTypeManager = {}
		@updateMerger = SandboxedModule.require modulePath, requires:
			'../Editor/EditorController': @editorController
			'../Project/ProjectLocator': @projectLocator
			'../Project/ProjectEntityHandler': @projectEntityHandler
			'fs': @fs
			'../Uploads/FileTypeManager':@FileTypeManager
			'settings-sharelatex':{path:{dumpPath:"dump_here"}}
			'logger-sharelatex':
				log: ->
				err: ->
			"metrics-sharelatex": 
				Timer:->
					done:->
		@project_id = "project_id_here"
		@user_id = "mock-user-id"
		@source = "dropbox"
		@update = new BufferedStream()
		@update.headers = {}

	describe 'mergeUpdate :', ->
		beforeEach ->
			@path = "/doc1"
			@fsPath = "file/system/path.tex"
			@updateMerger.p.writeStreamToDisk = sinon.stub().callsArgWith(3, null, @fsPath)
			@FileTypeManager.isBinary = sinon.stub()

		it 'should get the element id', (done)->
			@projectLocator.findElementByPath = sinon.spy()
			@updateMerger.mergeUpdate @user_id, @project_id, @path, @update, @source, =>
			@projectLocator.findElementByPath.calledWith(@project_id, @path).should.equal true
			done()

		it 'should process update as doc when it is a doc', (done)->
			doc_id = "231312s"
			@FileTypeManager.isBinary.callsArgWith(2, null, false)
			@projectLocator.findElementByPath = (_, __, cb)->cb(null, {_id:doc_id})
			@updateMerger.p.processDoc = sinon.stub().callsArgWith(6)
			filePath = "/folder/doc.tex"

			@updateMerger.mergeUpdate @user_id, @project_id, filePath, @update, @source, =>
				@FileTypeManager.isBinary.calledWith(filePath, @fsPath).should.equal true
				@updateMerger.p.processDoc.calledWith(@project_id, doc_id, @user_id, @fsPath, filePath, @source).should.equal true
				@fs.unlink.calledWith(@fsPath).should.equal true
				done()

		it 'should process update as file when it is not a doc', (done)->
			file_id = "1231"
			@projectLocator.findElementByPath = (_, __, cb)->cb(null, {_id:file_id})
			@FileTypeManager.isBinary.callsArgWith(2, null, true)
			@updateMerger.p.processFile = sinon.stub().callsArgWith(5)
			filePath = "/folder/file1.png"

			@updateMerger.mergeUpdate @user_id, @project_id, filePath, @update, @source, =>
				@updateMerger.p.processFile.calledWith(@project_id, file_id, @fsPath, filePath, @source).should.equal true
				@FileTypeManager.isBinary.calledWith(filePath, @fsPath).should.equal true
				@fs.unlink.calledWith(@fsPath).should.equal true
				done()


	describe 'processDoc :', (done)->
		beforeEach ->
			@doc_id = "312312klnkld"
			@docLines = "\\documentclass{article}\n\\usepackage[utf8]{inputenc}\n\n\\title{42}\n\\author{Jane Doe}\n\\date{June 2011}"
			@splitDocLines = @docLines.split("\n")
			@fs.readFile = sinon.stub().callsArgWith(2, null, @docLines)

		it 'should set the doc text in the editor controller', (done)->
			@editorController.setDoc = ->
			mock = sinon.mock(@editorController).expects("setDoc").withArgs(@project_id, @doc_id, @user_id, @splitDocLines, @source).callsArg(5)

			@update.write(@docLines)
			@update.end()

			@updateMerger.p.processDoc @project_id, @doc_id, @user_id, @update, "path", @source, ->
				mock.verify()
				done()

		it 'should create a new doc when it doesnt exist', (done)->
			folder = {_id:"adslkjioj"}
			docName = "main.tex"
			path = "folder1/folder2/#{docName}"
			@editorController.mkdirp = sinon.stub().withArgs(@project_id).callsArgWith(2, null, [folder], folder)
			@editorController.addDoc = ->
			mock = sinon.mock(@editorController).expects("addDoc").withArgs(@project_id, folder._id, docName, @splitDocLines, @source).callsArg(5)

			@update.write(@docLines)
			@update.end()

			@updateMerger.p.processDoc @project_id, undefined, @user_id, @update, path, @source, ->
				mock.verify()
				done()

	describe 'processFile :', (done)->
		beforeEach ->
			@file_id = "file_id_here"
			@folder_id = "folder_id_here"
			@path = "folder/file.png"
			@folder = _id: @folder_id
			@fileName = "file.png"
			@fsPath = "fs/path.tex"
			@editorController.addFile = sinon.stub().callsArg(5)
			@editorController.replaceFile = sinon.stub().callsArg(4)
			@editorController.deleteEntity = sinon.stub()
			@editorController.mkdirp = sinon.stub().withArgs(@project_id).callsArgWith(2, null, [@folder], @folder)
			@updateMerger.p.writeStreamToDisk = sinon.stub().withArgs(@project_id, @file_id, @update).callsArgWith(3, null, @fsPath)

		it 'should replace file if the file already exists', (done)->
			@updateMerger.p.processFile @project_id, @file_id, @fsPath, @path, @source, =>
				@editorController.addFile.called.should.equal false
				@editorController.replaceFile.calledWith(@project_id, @file_id, @fsPath, @source).should.equal true
				done()

		it 'should call add file if the file does not exist', (done)->
			@updateMerger.p.processFile @project_id, undefined, @fsPath, @path, @source, =>
				@editorController.mkdirp.calledWith(@project_id, "folder/").should.equal true
				@editorController.addFile.calledWith(@project_id, @folder_id, @fileName, @fsPath, @source).should.equal true
				@editorController.replaceFile.called.should.equal false
				done()

	describe 'delete entity :', (done)->

		beforeEach ->
			@path = "folder/doc1"
			@type = "mock-type"
			@editorController.deleteEntity = ->
			@entity_id = "entity_id_here"
			@entity = _id:@entity_id
			@projectLocator.findElementByPath = (project_id, path, cb)=> cb(null, @entity, @type)

		it 'should get the element id', ->
			@projectLocator.findElementByPath = sinon.spy()
			@updateMerger.deleteUpdate @project_id, @path, @source, ->
			@projectLocator.findElementByPath.calledWith(@project_id, @path).should.equal true

		it 'should delete the entity in the editor controller with the correct type', (done)->
			@entity.lines = []
			mock = sinon.mock(@editorController).expects("deleteEntity").withArgs(@project_id, @entity_id, @type, @source).callsArg(4)
			@updateMerger.deleteUpdate @project_id, @path, @source, ->
				mock.verify()
				done()

	
