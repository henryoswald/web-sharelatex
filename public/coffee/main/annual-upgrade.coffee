define [
	"base"
], (App) ->
	App.controller "AnnualUpgradeController",  ($scope, $http, $modal) ->

		MESSAGES_URL = "/user/subscription/upgrade-annual"

		$scope.upgradeComplete = false
		savings = 
			student:"19.2"
			collaborator:"36"
		$scope.$watch $scope.planName, ->
			$scope.yearlySaving = savings[$scope.planName]
			if $scope.planName == "annual"
				$scope.upgradeComplete = true
		$scope.completeAnnualUpgrade = ->
			body = 
				planName: $scope.planName
				_csrf : window.csrfToken

			$scope.inflight = true


			$http.post(MESSAGES_URL, body)
				.then ->
					$scope.upgradeComplete = true
				.catch ->
					console.log "something went wrong changing plan"