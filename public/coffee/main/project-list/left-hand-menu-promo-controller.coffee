define [
	"base"
], (App) ->

	App.controller 'LeftHandMenuPromoController', ($scope) ->

		$scope.hasProjects = window.data.projects.length > 0
		$scope.userHasNoSubscription = window.userHasNoSubscription

