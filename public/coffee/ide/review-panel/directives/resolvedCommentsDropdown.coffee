define [
	"base"
], (App) ->
	App.directive "resolvedCommentsDropdown", (_) ->
		restrict: "E"
		templateUrl: "resolvedCommentsDropdownTemplate"
		scope: 
			entries 	: "="
			threads 	: "="
			resolvedIds	: "="
			docs		: "="
			permissions: "="
			onOpen		: "&"
			onUnresolve	: "&"
			onDelete	: "&"
			isLoading	: "="

		link: (scope, element, attrs) ->
			scope.state = 
				isOpen: false

			scope.toggleOpenState = () ->
				scope.state.isOpen = !scope.state.isOpen
				if (scope.state.isOpen)
					scope.onOpen()
						.then () -> filterResolvedComments()

			scope.resolvedComments = []

			scope.handleUnresolve = (threadId) ->
				scope.onUnresolve({ threadId })
				scope.resolvedComments = scope.resolvedComments.filter (c) -> c.threadId != threadId

			scope.handleDelete = (entryId, docId, threadId) ->
				scope.onDelete({ entryId, docId, threadId })
				scope.resolvedComments = scope.resolvedComments.filter (c) -> c.threadId != threadId

			getDocNameById = (docId) ->
				doc = _.find(scope.docs, (doc) -> doc.doc.id == docId)
				if doc?
					return doc.path
				else 
					return null

			filterResolvedComments = () ->
				scope.resolvedComments = []

				for docId, docEntries of scope.entries
					for entryId, entry of docEntries
						if entry.type == "comment" and scope.threads[entry.thread_id]?.resolved?
							resolvedComment = angular.copy scope.threads[entry.thread_id]

							resolvedComment.content = entry.content
							resolvedComment.threadId = entry.thread_id
							resolvedComment.entryId = entryId
							resolvedComment.docId = docId
							resolvedComment.docName = getDocNameById(docId)

							scope.resolvedComments.push(resolvedComment)
