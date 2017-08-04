define [
	"ide/editor/AceShareJsCodec"
], (AceShareJsCodec) ->
	class CursorPositionManager
		constructor: (@$scope, @editor, @element, @localStorage) ->

			onChangeCursor = (e) =>
				@emitCursorUpdateEvent(e)

			@editor.on "changeSession", (e) =>
				if e.oldSession?
					@storeCursorPosition(e.oldSession)
					@storeScrollTopPosition(e.oldSession)

				@doc_id = @$scope.sharejsDoc?.doc_id

				e.oldSession?.selection.off 'changeCursor', onChangeCursor
				e.session.selection.on 'changeCursor', onChangeCursor

				setTimeout () =>
					@gotoStoredPosition()
				, 0

			$(window).on "unload", () =>
				@storeCursorPosition(@editor.getSession())
				@storeScrollTopPosition(@editor.getSession())

			@$scope.$on "#{@$scope.name}:gotoLine", (e, line, column) =>
				if line?
					setTimeout () =>
						@gotoLine(line, column)
					, 10 # Hack: Must happen after @gotoStoredPosition
			
			@$scope.$on "#{@$scope.name}:gotoOffset", (e, offset) =>
				if offset?
					setTimeout () =>
						@gotoOffset(offset)
					, 10 # Hack: Must happen after @gotoStoredPosition

			@$scope.$on "#{@$scope.name}:clearSelection", (e) =>
				@editor.selection.clearSelection()

		storeScrollTopPosition: (session) ->
			if @doc_id?
				docPosition = @localStorage("doc.position.#{@doc_id}") || {}
				docPosition.scrollTop = session.getScrollTop()
				@localStorage("doc.position.#{@doc_id}", docPosition)

		storeCursorPosition: (session) ->
			if @doc_id?
				docPosition = @localStorage("doc.position.#{@doc_id}") || {}
				docPosition.cursorPosition = session.selection.getCursor()
				@localStorage("doc.position.#{@doc_id}", docPosition)
			
		emitCursorUpdateEvent: () ->
			cursor = @editor.getCursorPosition()
			@$scope.$emit "cursor:#{@$scope.name}:update", cursor

		gotoStoredPosition: () ->
			return if !@doc_id?
			pos = @localStorage("doc.position.#{@doc_id}") || {}
			@ignoreCursorPositionChanges = true
			@editor.moveCursorToPosition(pos.cursorPosition or {row: 0, column: 0})
			@editor.getSession().setScrollTop(pos.scrollTop or 0)
			delete @ignoreCursorPositionChanges

		gotoLine: (line, column) ->
			@editor.gotoLine(line, column)
			@editor.scrollToLine(line,true,true) # centre and animate
			@editor.focus()

		gotoOffset: (offset) ->
			lines = @editor.getSession().getDocument().getAllLines()
			position = AceShareJsCodec.shareJsOffsetToAcePosition(offset, lines)
			@gotoLine(position.row + 1, position.column)