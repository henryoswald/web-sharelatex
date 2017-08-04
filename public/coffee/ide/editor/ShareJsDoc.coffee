define [
	"utils/EventEmitter"
	"libs/sharejs"
], (EventEmitter, ShareJs) ->
	SINGLE_USER_FLUSH_DELAY = 1000 #ms

	class ShareJsDoc extends EventEmitter
		constructor: (@doc_id, docLines, version, @socket) ->
			# Dencode any binary bits of data
			# See http://ecmanaut.blogspot.co.uk/2006/07/encoding-decoding-utf8-in-javascript.html
			@type = "text"
			docLines = (decodeURIComponent(escape(line)) for line in docLines)
			snapshot = docLines.join("\n")
			@track_changes = false

			@connection = {
				send: (update) =>
					@_startInflightOpTimeout(update)
					if window.disconnectOnUpdate? and Math.random() < window.disconnectOnUpdate
						sl_console.log "Disconnecting on update", update
						window._ide.socket.socket.disconnect()
					if window.dropUpdates? and Math.random() < window.dropUpdates
						sl_console.log "Simulating a lost update", update
						return
					if @track_changes
						update.meta ?= {}
						update.meta.tc = @track_changes_id_seeds.inflight
					@socket.emit "applyOtUpdate", @doc_id, update, (error) =>
						return @_handleError(error) if error?
				state: "ok"
				id:    @socket.socket.sessionid
			}

			@_doc = new ShareJs.Doc @connection, @doc_id,
				type: @type
			@_doc.setFlushDelay(SINGLE_USER_FLUSH_DELAY)
			@_doc.on "change", (args...) =>
				@trigger "change", args...
			@_doc.on "acknowledge", () =>
				@lastAcked = new Date() # note time of last ack from server for an op we sent
				@trigger "acknowledge"
			@_doc.on "remoteop", (args...) =>
				# As soon as we're working with a collaborator, start sending
				# ops as quickly as possible for low latency.
				@_doc.setFlushDelay(0)
				@trigger "remoteop", args...
			@_doc.on "flipped_pending_to_inflight", () =>
				@trigger "flipped_pending_to_inflight"
			@_doc.on "error", (e) =>
				@_handleError(e)

			@_bindToDocChanges(@_doc)

			@processUpdateFromServer
				open: true
				v: version
				snapshot: snapshot

		submitOp: (args...) -> @_doc.submitOp(args...)

		processUpdateFromServer: (message) ->
			try
				@_doc._onMessage message
			catch error
				# Version mismatches are thrown as errors
				console.log error
				@_handleError(error)

			if message?.meta?.type == "external"
				@trigger "externalUpdate", message

		catchUp: (updates) ->
			for update, i in updates
				update.v   = @_doc.version
				update.doc = @doc_id
				@processUpdateFromServer(update)

		getSnapshot: () -> @_doc.snapshot
		getVersion: () -> @_doc.version
		getType: () -> @type

		clearInflightAndPendingOps: () ->
			@_doc.inflightOp = null
			@_doc.inflightCallbacks = []
			@_doc.pendingOp = null
			@_doc.pendingCallbacks = []

		flushPendingOps: () ->
			# This will flush any ops that are pending.
			# If there is an inflight op it will do nothing.
			@_doc.flush()

		updateConnectionState: (state) ->
			sl_console.log "[updateConnectionState] Setting state to #{state}"
			@connection.state = state
			@connection.id = @socket.socket.sessionid
			@_doc.autoOpen = false
			@_doc._connectionStateChanged(state)
			@lastAcked = null # reset the last ack time when connection changes

		hasBufferedOps: () ->
			@_doc.inflightOp? or @_doc.pendingOp?

		getInflightOp: () -> @_doc.inflightOp
		getPendingOp: () -> @_doc.pendingOp
		getRecentAck: () ->
			# check if we have received an ack recently (within the flush delay)
			@lastAcked? and new Date() - @lastAcked < @_doc._flushDelay
		getOpSize: (op) ->
			# compute size of an op from its components
			# (total number of characters inserted and deleted)
			size = 0
			for component in op or []
				if component?.i?
					size += component.i.length
				if component?.d?
					size += component.d.length
			return size

		attachToAce: (ace) -> @_doc.attach_ace(ace, false, window.maxDocLength)
		detachFromAce: () -> @_doc.detach_ace?()

		INFLIGHT_OP_TIMEOUT: 5000 # Retry sending ops after 5 seconds without an ack
		WAIT_FOR_CONNECTION_TIMEOUT: 500 # If we're waiting for the project to join, try again in 0.5 seconds
		_startInflightOpTimeout: (update) ->
			@_startFatalTimeoutTimer(update)
			retryOp = () =>
				# Only send the update again if inflightOp is still populated
				# This can be cleared when hard reloading the document in which
				# case we don't want to keep trying to send it.
				sl_console.log "[inflightOpTimeout] Trying op again"
				if @_doc.inflightOp?
					# When there is a socket.io disconnect, @_doc.inflightSubmittedIds
					# is updated with the socket.io client id of the current op in flight
					# (meta.source of the op).
					# @connection.id is the client id of the current socket.io session.
					# So we need both depending on whether the op was submitted before
					# one or more disconnects, or if it was submitted during the current session.
					update.dupIfSource = [@connection.id, @_doc.inflightSubmittedIds...]
					
					# We must be joined to a project for applyOtUpdate to work on the real-time
					# service, so don't send an op if we're not. Connection state is set to 'ok'
					# when we've joined the project
					if @connection.state != "ok"
						sl_console.log "[inflightOpTimeout] Not connected, retrying in 0.5s"
						timer = setTimeout retryOp, @WAIT_FOR_CONNECTION_TIMEOUT
					else
						sl_console.log "[inflightOpTimeout] Sending"
						@connection.send(update)
			
			timer = setTimeout retryOp, @INFLIGHT_OP_TIMEOUT
			@_doc.inflightCallbacks.push () =>
				@_clearFatalTimeoutTimer()
				clearTimeout timer

		FATAL_OP_TIMEOUT: 30000 # 30 seconds
		_startFatalTimeoutTimer: (update) ->
			# If an op doesn't get acked within FATAL_OP_TIMEOUT, something has
			# gone unrecoverably wrong (the op will have been retried multiple times)
			return if @_timeoutTimer?
			@_timeoutTimer = setTimeout () =>
				@_clearFatalTimeoutTimer()
				@trigger "op:timeout", update
			, @FATAL_OP_TIMEOUT
		
		_clearFatalTimeoutTimer: () ->
			return if !@_timeoutTimer?
			clearTimeout @_timeoutTimer
			@_timeoutTimer = null

		_handleError: (error, meta = {}) ->
			@trigger "error", error, meta

		_bindToDocChanges: (doc) ->
			submitOp = doc.submitOp
			doc.submitOp = (args...) =>
				@trigger "op:sent", args...
				doc.pendingCallbacks.push () =>
					@trigger "op:acknowledged", args...
				submitOp.apply(doc, args)

			flush = doc.flush
			doc.flush = (args...) =>
				@trigger "flush", doc.inflightOp, doc.pendingOp, doc.version
				flush.apply(doc, args)
