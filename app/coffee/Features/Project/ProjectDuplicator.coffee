projectCreationHandler = require('./ProjectCreationHandler')
projectEntityHandler = require('./ProjectEntityHandler')
projectLocator = require('./ProjectLocator')
projectOptionsHandler = require('./ProjectOptionsHandler')
DocumentUpdaterHandler = require("../DocumentUpdater/DocumentUpdaterHandler")
DocstoreManager = require "../Docstore/DocstoreManager"
ProjectGetter = require("./ProjectGetter")
_ = require('underscore')
async = require('async')
logger = require("logger-sharelatex")


module.exports = ProjectDuplicator =

	_copyDocs: (newProject, originalRootDoc, originalFolder, desFolder, docContents, callback)->
		setRootDoc = _.once (doc_id)->
			projectEntityHandler.setRootDoc newProject._id, doc_id
		docs = originalFolder.docs or []
		jobs = docs.map (doc)->
			return (cb)->
				if !doc?._id?
					return callback()
				content = docContents[doc._id.toString()]
				projectEntityHandler.addDocWithProject newProject, desFolder._id, doc.name, content.lines, (err, newDoc)->
					if err?
						logger.err err:err, "error copying doc"
						return callback(err)
					if originalRootDoc? and newDoc.name == originalRootDoc.name
						setRootDoc newDoc._id
					cb()

		async.series jobs, callback

	_copyFiles: (newProject, originalProject_id, originalFolder, desFolder, callback)->
		fileRefs = originalFolder.fileRefs or []
		jobs = fileRefs.map (file)->
			return (cb)->
				projectEntityHandler.copyFileFromExistingProjectWithProject newProject, desFolder._id, originalProject_id, file, cb
		async.parallelLimit jobs, 5, callback


	_copyFolderRecursivly: (newProject_id, originalProject_id, originalRootDoc, originalFolder, desFolder, docContents, callback)->
		ProjectGetter.getProject newProject_id, {rootFolder:true, name:true}, (err, newProject)->
			if err?
				logger.err project_id:newProject_id, "could not get project"
				return callback(err)

			folders = originalFolder.folders or []

			jobs = folders.map (childFolder)->
				return (cb)->
					if !childFolder?._id?
						return cb()
					projectEntityHandler.addFolderWithProject newProject, desFolder?._id, childFolder.name, (err, newFolder)->
						return cb(err) if err?
						ProjectDuplicator._copyFolderRecursivly newProject_id, originalProject_id, originalRootDoc, childFolder, newFolder, docContents, cb

			jobs.push (cb)->
				ProjectDuplicator._copyFiles newProject, originalProject_id, originalFolder, desFolder, cb
			jobs.push (cb)->
				ProjectDuplicator._copyDocs newProject, originalRootDoc, originalFolder, desFolder, docContents, cb

			async.series jobs, callback

	duplicate: (owner, originalProject_id, newProjectName, callback)->

		jobs = 
			flush: (cb)->
				DocumentUpdaterHandler.flushProjectToMongo originalProject_id, cb
			originalProject: (cb)->
				ProjectGetter.getProject originalProject_id, {compiler:true, rootFolder:true, rootDoc_id:true}, cb
			newProject: (cb)->
				projectCreationHandler.createBlankProject owner._id, newProjectName, cb
			originalRootDoc: (cb)->
				projectLocator.findRootDoc {project_id:originalProject_id}, cb
			docContentsArray: (cb)-> 
				DocstoreManager.getAllDocs originalProject_id, cb

		async.series jobs, (err, results)->
			if err?
				logger.err err:err, originalProject_id:originalProject_id, "error duplicating project"
				return callback(err)
			{originalProject, newProject, originalRootDoc, docContentsArray} = results

			originalRootDoc = originalRootDoc?[0]

			docContents = {}
			for docContent in docContentsArray
				docContents[docContent._id] = docContent
			
			projectOptionsHandler.setCompiler newProject._id, originalProject.compiler, ->

			ProjectDuplicator._copyFolderRecursivly newProject._id, originalProject_id, originalRootDoc, originalProject.rootFolder[0], newProject.rootFolder[0], docContents, ->
				if err?
					logger.err err:err, originalProject_id:originalProject_id,  newProjectName:newProjectName, "error cloning project"
				callback(err, newProject)
