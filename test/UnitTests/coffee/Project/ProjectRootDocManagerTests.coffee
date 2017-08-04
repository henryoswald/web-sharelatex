chai = require('chai')
should = chai.should()
sinon = require("sinon")
modulePath = "../../../../app/js/Features/Project/ProjectRootDocManager.js"
SandboxedModule = require('sandboxed-module')

describe 'ProjectRootDocManager', ->
	beforeEach ->
		@project_id = "project-123"
		@sl_req_id = "sl-req-id-123"
		@callback = sinon.stub()
		@ProjectRootDocManager = SandboxedModule.require modulePath, requires:
			"./ProjectEntityHandler" : @ProjectEntityHandler = {}
	
	describe "setRootDocAutomatically", ->
		describe "when there is a suitable root doc", ->
			beforeEach (done)->
				@docs =
					"/chapter1.tex":
						_id: "doc-id-1"
						lines: ["something else","\\begin{document}", "Hello world", "\\end{document}"]
					"/main.tex":
						_id: "doc-id-2"
						lines: ["different line","\\documentclass{article}", "\\input{chapter1}"]
					"/nested/chapter1a.tex":
						_id: "doc-id-3"
						lines: ["Hello world"]
					"/nested/chapter1b.tex":
						_id: "doc-id-4"
						lines: ["Hello world"]

				@ProjectEntityHandler.getAllDocs = sinon.stub().callsArgWith(1, null, @docs)
				@ProjectEntityHandler.setRootDoc = sinon.stub().callsArgWith(2)
				@ProjectRootDocManager.setRootDocAutomatically @project_id, done

			it "should check the docs of the project", ->
				@ProjectEntityHandler.getAllDocs.calledWith(@project_id)
					.should.equal true

			it "should set the root doc to the doc containing a documentclass", ->
				@ProjectEntityHandler.setRootDoc.calledWith(@project_id, "doc-id-2")
					.should.equal true

		describe "when the root doc is an Rtex file", ->
			beforeEach ->
				@docs =
					"/chapter1.tex":
						_id: "doc-id-1"
						lines: ["\\begin{document}", "Hello world", "\\end{document}"]
					"/main.Rtex":
						_id: "doc-id-2"
						lines: ["\\documentclass{article}", "\\input{chapter1}"]
				@ProjectEntityHandler.getAllDocs = sinon.stub().callsArgWith(1, null, @docs)
				@ProjectEntityHandler.setRootDoc = sinon.stub().callsArgWith(2)
				@ProjectRootDocManager.setRootDocAutomatically @project_id, @callback

			it "should set the root doc to the doc containing a documentclass", ->
				@ProjectEntityHandler.setRootDoc.calledWith(@project_id, "doc-id-2")
					.should.equal true

		describe "when there is no suitable root doc", ->
			beforeEach (done)->
				@docs =
					"/chapter1.tex":
						_id: "doc-id-1"
						lines: ["\\begin{document}", "Hello world", "\\end{document}"]
					"/style.bst":
						_id: "doc-id-2"
						lines: ["%Example: \\documentclass{article}"]
				@ProjectEntityHandler.getAllDocs = sinon.stub().callsArgWith(1, null, @docs)
				@ProjectEntityHandler.setRootDoc = sinon.stub().callsArgWith(2)
				@ProjectRootDocManager.setRootDocAutomatically @project_id, done

			it "should not set the root doc to the doc containing a documentclass", ->
				@ProjectEntityHandler.setRootDoc.called.should.equal false

