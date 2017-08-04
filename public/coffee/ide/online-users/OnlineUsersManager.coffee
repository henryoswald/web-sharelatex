define [
	"ide/colors/ColorManager"
	"libs/md5"
	"ide/online-users/controllers/OnlineUsersController"
], (ColorManager) ->
	class OnlineUsersManager

		cursorUpdateInterval:500

		constructor: (@ide, @$scope) ->
			@$scope.onlineUsers = {}
			@$scope.onlineUserCursorHighlights = {}
			@$scope.onlineUsersArray = []

			@$scope.$on "cursor:editor:update", (event, position) =>
				@sendCursorPositionUpdate(position)
			
			@$scope.$on "project:joined", () =>
				@ide.socket.emit "clientTracking.getConnectedUsers", (error, connectedUsers) =>
					@$scope.onlineUsers = {}
					for user in connectedUsers or []
						if user.client_id == @ide.socket.socket.sessionid
							# Don't store myself
							continue
						# Store data in the same format returned by clientTracking.clientUpdated

						@$scope.onlineUsers[user.client_id] = {
							id:      user.client_id
							user_id: user.user_id
							email:   user.email
							name:    "#{user.first_name} #{user.last_name}"
							doc_id:  user.cursorData?.doc_id
							row:     user.cursorData?.row
							column:  user.cursorData?.column
						}
					@refreshOnlineUsers()

			@ide.socket.on "clientTracking.clientUpdated", (client) =>
				if client.id != @ide.socket.socket.sessionid # Check it's not me!
					@$scope.$apply () =>
						@$scope.onlineUsers[client.id] = client
						@refreshOnlineUsers()

			@ide.socket.on "clientTracking.clientDisconnected", (client_id) =>
				@$scope.$apply () =>
					delete @$scope.onlineUsers[client_id]
					@refreshOnlineUsers()
					
			@$scope.getHueForUserId = (user_id) =>
				ColorManager.getHueForUserId(user_id)

		refreshOnlineUsers: () ->
			@$scope.onlineUsersArray = []
			
			for client_id, user of @$scope.onlineUsers
				if user.doc_id?
					user.doc = @ide.fileTreeManager.findEntityById(user.doc_id)

				if user.name?.trim().length == 0
					user.name = user.email.trim()
				
				user.initial = user.name?[0]
				if !user.initial or user.initial == " "
					user.initial = "?"

				@$scope.onlineUsersArray.push user

			@$scope.onlineUserCursorHighlights = {}
			for client_id, client of @$scope.onlineUsers
				doc_id = client.doc_id
				continue if !doc_id? or !client.row? or !client.column?
				@$scope.onlineUserCursorHighlights[doc_id] ||= []
				@$scope.onlineUserCursorHighlights[doc_id].push {
					label: client.name
					cursor:
						row: client.row
						column: client.column
					hue: ColorManager.getHueForUserId(client.user_id)
				}

			if @$scope.onlineUsersArray.length > 0
				delete @cursorUpdateTimeout
				@cursorUpdateInterval = 500
			else
				delete @cursorUpdateTimeout
				@cursorUpdateInterval = 60 * 1000 * 5


		sendCursorPositionUpdate: (position) ->
			if position?
				@$scope.currentPosition = position  # keep track of the latest position
			if !@cursorUpdateTimeout?
				@cursorUpdateTimeout = setTimeout ()=>
					doc_id   = @$scope.editor.open_doc_id
					# always send the latest position to other clients
					@ide.socket.emit "clientTracking.updatePosition", {
						row: @$scope.currentPosition?.row
						column: @$scope.currentPosition?.column
						doc_id: doc_id
					}

					delete @cursorUpdateTimeout
				, @cursorUpdateInterval

