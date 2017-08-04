spies = require('chai-spies')
chai = require('chai').use(spies)
assert = require('chai').assert
should = chai.should()
modulePath = "../../../../app/js/Features/Project/ProjectLocator"
SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
Errors = require "../../../../app/js/Features/Errors/Errors"
expect = require("chai").expect
Project = class Project

project = _id : "1234566", rootFolder:[]
rootDoc = name:"rootDoc", _id:"das239djd"
doc1 = name:"otherDoc.txt", _id:"dsad2ddd"
doc2 = name:"docname.txt", _id:"dsad2ddddd"
file1 = name:"file1", _id:"dsa9lkdsad"
subSubFile = name:"subSubFile", _id:"d1d2dk"
subSubDoc = name:"subdoc.txt", _id:"321dmdwi"
secondSubFolder = name:"secondSubFolder", _id:"dsa3e23", docs:[subSubDoc], fileRefs:[subSubFile], folders:[]
subFolder = name:"subFolder", _id:"dsadsa93", folders:[secondSubFolder, null], docs:[], fileRefs:[]
subFolder1 = name:"subFolder1", _id:"123asdjoij"

rootFolder =
	_id : "123sdskd"
	docs:[doc1, doc2, null, rootDoc]
	fileRefs:[file1]
	folders:[subFolder1, subFolder]

project.rootFolder[0] = rootFolder
project.rootDoc_id = rootDoc._id


describe 'ProjectLocator', ->

	beforeEach ->
		Project.getProject = (project_id, fields, callback)=>
			callback(null, project)

		Project.findById = (project_id, callback)=>
			callback(null, project)
		@ProjectGetter = 
			getProject: sinon.stub().callsArgWith(2, null, project)
		@locator = SandboxedModule.require modulePath, requires:
			'../../models/Project':{Project:Project}
			'../../models/User':{User:@User}
			"./ProjectGetter":@ProjectGetter
			'logger-sharelatex':
				log:->
				err:->
				warn: ->

	describe 'finding a doc', ->
		it 'finds one at the root level', (done)->
			@locator.findElement {project_id:project._id, element_id:doc2._id, type:"docs"}, (err, foundElement, path, parentFolder)->
				assert(!err?)
				foundElement._id.should.equal doc2._id
				path.fileSystem.should.equal "/#{doc2.name}"
				parentFolder._id.should.equal project.rootFolder[0]._id
				path.mongo.should.equal "rootFolder.0.docs.1"
				done()

		it 'when it is nested', (done)->
			@locator.findElement {project_id:project._id, element_id:subSubDoc._id, type:"doc"}, (err, foundElement, path, parentFolder)->
				assert(!err?)
				should.equal foundElement._id, subSubDoc._id
				path.fileSystem.should.equal "/#{subFolder.name}/#{secondSubFolder.name}/#{subSubDoc.name}"
				parentFolder._id.should.equal secondSubFolder._id
				path.mongo.should.equal "rootFolder.0.folders.1.folders.0.docs.0"
				done()

		it 'should give error if element could not be found', (done)->
			@locator.findElement {project_id:project._id, element_id:"ddsd432nj42", type:"docs"}, (err, foundElement, path, parentFolder)->
				err.should.deep.equal new Errors.NotFoundError("entity not found")
				done()


	describe 'finding a folder', ->
		it 'should return root folder when looking for root folder', (done)->
			@locator.findElement {project_id:project._id, element_id:rootFolder._id, type:"folder"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal rootFolder._id
				done()

		it 'when at root', (done)->
			@locator.findElement {project_id:project._id, element_id:subFolder._id, type:"folder"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal subFolder._id
				path.fileSystem.should.equal "/#{subFolder.name}"
				parentFolder._id.should.equal rootFolder._id
				path.mongo.should.equal "rootFolder.0.folders.1"
				done()

		it 'when deeply nested', (done)->
			@locator.findElement {project_id:project._id, element_id:secondSubFolder._id, type:"folder"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal secondSubFolder._id
				path.fileSystem.should.equal "/#{subFolder.name}/#{secondSubFolder.name}"
				parentFolder._id.should.equal subFolder._id
				path.mongo.should.equal "rootFolder.0.folders.1.folders.0"
				done()

	describe 'finding a file', ->
		it 'when at root', (done)->
			@locator.findElement {project_id:project._id, element_id:file1._id, type:"fileRefs"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal file1._id
				path.fileSystem.should.equal "/#{file1.name}"
				parentFolder._id.should.equal rootFolder._id
				path.mongo.should.equal "rootFolder.0.fileRefs.0"
				done()

		it 'when deeply nested', (done)->
			@locator.findElement {project_id:project._id, element_id:subSubFile._id, type:"fileRefs"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal subSubFile._id
				path.fileSystem.should.equal "/#{subFolder.name}/#{secondSubFolder.name}/#{subSubFile.name}"
				parentFolder._id.should.equal secondSubFolder._id
				path.mongo.should.equal "rootFolder.0.folders.1.folders.0.fileRefs.0"
				done()

	describe 'finding an element with wrong element type', ->
		it 'should add an s onto the element type', (done)->
			@locator.findElement {project_id:project._id, element_id:subSubDoc._id, type:"doc"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal subSubDoc._id
				done()

		it 'should convert file to fileRefs', (done)->
			@locator.findElement {project_id:project._id, element_id:file1._id, type:"fileRefs"}, (err, foundElement, path, parentFolder)->
				assert(!err)
				foundElement._id.should.equal file1._id
				done()

	describe 'should be able to take actual project as well as id', ->
		doc3 =
			_id:"123dsdj3"
			name:"doc3"
		rootFolder2 =
			_id : "123sddedskd"
			docs:[doc3]
		project2 =
			_id : "1234566"
			rootFolder:[rootFolder2]
		it 'should find doc in project', (done)->
			@locator.findElement {project:project2, element_id:doc3._id, type:"docs"}, (err, foundElement, path, parentFolder)->
				assert(!err?)
				foundElement._id.should.equal doc3._id
				path.fileSystem.should.equal "/#{doc3.name}"
				parentFolder._id.should.equal project2.rootFolder[0]._id
				path.mongo.should.equal "rootFolder.0.docs.0"
				done()

	describe 'finding root doc', ->
		it 'should return root doc when passed project', (done)->
			@locator.findRootDoc project, (err, doc)->
				assert !err?
				doc._id.should.equal rootDoc._id
				done()

		it 'should return root doc when passed project_id', (done)->
			@locator.findRootDoc project._id, (err, doc)->
				assert !err?
				doc._id.should.equal rootDoc._id
				done()
		
		it 'should return null when the project has no rootDoc', (done) ->
			project.rootDoc_id = null
			@locator.findRootDoc project, (err, doc)->
				assert !err?
				expect(doc).to.equal null
				done()
		
		it 'should return null when the rootDoc_id no longer exists', (done) ->
			project.rootDoc_id = "doesntexist"
			@locator.findRootDoc project, (err, doc)->
				assert !err?
				expect(doc).to.equal null
				done()

	describe 'findElementByPath', ->

		it 'should take a doc path and return the element for a root level document', (done)->
			path = "#{doc1.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal doc1
				expect(type).to.equal "doc"
				done()

		it 'should take a doc path and return the element for a root level document with a starting slash', (done)->
			path = "/#{doc1.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal doc1
				expect(type).to.equal "doc"
				done()
				
		it 'should take a doc path and return the element for a nested document', (done)->
			path = "#{subFolder.name}/#{secondSubFolder.name}/#{subSubDoc.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal subSubDoc
				expect(type).to.equal "doc"
				done()

		it 'should take a file path and return the element for a root level document', (done)->
			path = "#{file1.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal file1
				expect(type).to.equal "file"
				done()

		it 'should take a file path and return the element for a nested document', (done)->
			path = "#{subFolder.name}/#{secondSubFolder.name}/#{subSubFile.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal subSubFile
				expect(type).to.equal "file"
				done()

		it 'should take a file path and return the element for a nested document case insenstive', (done)->
			path = "#{subFolder.name.toUpperCase()}/#{secondSubFolder.name.toUpperCase()}/#{subSubFile.name.toUpperCase()}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal subSubFile
				expect(type).to.equal "file"
				done()

		it 'should take a file path and return the element for a nested folder', (done)->
			path = "#{subFolder.name}/#{secondSubFolder.name}"
			@locator.findElementByPath project._id, path, (err, element, type)->
				element.should.deep.equal secondSubFolder
				expect(type).to.equal "folder"
				done()

		it 'should take a file path and return the root folder', (done)->
			@locator.findElementByPath project._id, "/", (err, element, type)->
				element.should.deep.equal rootFolder
				expect(type).to.equal "folder"
				done()

		it 'should return an error if the file can not be found inside know folder', (done)->
			@locator.findElementByPath project._id, "#{subFolder.name}/#{secondSubFolder.name}/exist.txt", (err, element, type)->
				err.should.not.equal undefined
				assert.equal element, undefined
				expect(type).to.be.undefined
				done()

		it 'should return an error if the file can not be found inside unknown folder', (done)->
			@locator.findElementByPath project._id, "this/does/not/exist.txt", (err, element, type)->
				err.should.not.equal undefined
				assert.equal element, undefined
				expect(type).to.be.undefined
				done()


		describe "where duplicate folder exists", ->

			beforeEach ->
				@duplicateFolder = {name:"duplicate1", _id:"1234", folders:[{
					name: "1"
					docs:[{name:"main.tex", _id:"456"}]
					folders: []
					fileRefs: []
				}], docs:[@doc = {name:"main.tex", _id:"456"}], fileRefs:[]}
				@project =
					rootFolder:[
						folders: [@duplicateFolder, @duplicateFolder]
						fileRefs: []
						docs: []
					]
				Project.getProject = sinon.stub()
				Project.getProject.callsArgWith(2, null, @project)


			it "should not call the callback more than once", (done)->
				@locator.findElementByPath project._id, "#{@duplicateFolder.name}/#{@doc.name}", ->
					done() #mocha will throw exception if done called multiple times


			it "should not call the callback more than once when the path is longer than 1 level below the duplicate level", (done)->
				@locator.findElementByPath project._id, "#{@duplicateFolder.name}/1/main.tex", ->
					done() #mocha will throw exception if done called multiple times

		describe "with a null doc", ->
			beforeEach ->
				@project =
					rootFolder:[
						folders: []
						fileRefs: []
						docs: [{name:"main.tex"}, null, {name:"other.tex"}]
					]
				Project.getProject = sinon.stub()
				Project.getProject.callsArgWith(2, null, @project)

			it "should not crash with a null", (done)->
				callback = sinon.stub()
				@locator.findElementByPath project._id, "/other.tex", (err, element)->
					element.name.should.equal "other.tex"
					done()


		describe "with a null project", ->
			beforeEach ->
				@project =
					rootFolder:[
						folders: []
						fileRefs: []
						docs: [{name:"main.tex"}, null, {name:"other.tex"}]
					]
				Project.getProject = sinon.stub()
				Project.getProject.callsArgWith(2, null)

			it "should not crash with a null", (done)->
				callback = sinon.stub()
				@locator.findElementByPath project._id, "/other.tex", (err, element)->
					expect(err).to.exist
					done()			


	describe 'findUsersProjectByName finding a project by user_id and project name', ()->
		it 'should return the project from an array case insenstive', (done)->
			user_id = "123jojoidns"
			stubbedProject = {name:"findThis"}
			projects = [{name:"notThis"}, {name:"wellll"}, stubbedProject, {name:"Noooo"}]	
			@ProjectGetter.findAllUsersProjects = sinon.stub().callsArgWith(2, null, projects)
			@locator.findUsersProjectByName user_id, stubbedProject.name.toLowerCase(), (err, project)->
				project.should.equal stubbedProject
				done()

		it 'should return the project which is not archived', (done)->
			user_id = "123jojoidns"
			stubbedProject = {name:"findThis", _id:12331321}
			projects = [{name:"notThis"}, {name:"wellll"}, {name:"findThis",archived:true}, stubbedProject, {name:"findThis",archived:true}, {name:"Noooo"}]	
			@ProjectGetter.findAllUsersProjects = sinon.stub().callsArgWith(2, null, projects)
			@locator.findUsersProjectByName user_id, stubbedProject.name.toLowerCase(), (err, project)->
				project._id.should.equal stubbedProject._id
				done()

		it 'should search collab projects as well', (done)->
			user_id = "123jojoidns"
			stubbedProject = {name:"findThis"}
			projects = [{name:"notThis"}, {name:"wellll"}, {name:"Noooo"}]	
			@ProjectGetter.findAllUsersProjects = sinon.stub().callsArgWith(2, null, projects, [stubbedProject])
			@locator.findUsersProjectByName user_id, stubbedProject.name.toLowerCase(), (err, project)->
				project.should.equal stubbedProject
				done()

