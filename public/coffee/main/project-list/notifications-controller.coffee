define [
	"base"
], (App) ->

	App.controller "NotificationsController", ($scope, $http) ->
		for notification in $scope.notifications
			notification.hide = false

		$scope.dismiss = (notification) ->
			$http({
				url: "/notifications/#{notification._id}"
				method: "DELETE"
				headers:
					"X-Csrf-Token": window.csrfToken
			})
				.then () ->
					notification.hide = true
					
	App.controller "ProjectInviteNotificationController", ($scope, $http) ->
		# Shortcuts for translation keys
		$scope.projectName = $scope.notification.messageOpts.projectName
		$scope.userName = $scope.notification.messageOpts.userName

		$scope.accept = () ->
			$scope.notification.inflight = true
			$http({
				url: "/project/#{$scope.notification.messageOpts.projectId}/invite/token/#{$scope.notification.messageOpts.token}/accept"
				method: "POST"
				headers:
					"X-Csrf-Token": window.csrfToken
					"X-Requested-With": "XMLHttpRequest"
			})
				.then () ->
					$scope.notification.inflight = false
					$scope.notification.accepted = true
				.catch () ->
					$scope.notification.inflight = false
					$scope.notification.error = true