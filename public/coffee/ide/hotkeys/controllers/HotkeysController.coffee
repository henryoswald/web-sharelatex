define [
	"base"
	"ace/ace"
], (App) ->
	App.controller "HotkeysController", ($scope, $modal, event_tracking) ->
		$scope.openHotkeysModal = ->
			event_tracking.sendMB "ide-open-hotkeys-modal"

			$modal.open {
				templateUrl: "hotkeysModalTemplate"
				controller:  "HotkeysModalController"
				size: "lg"
				resolve:
					trackChangesVisible: () -> $scope.project.features.trackChangesVisible
			}
		
	App.controller "HotkeysModalController", ($scope, $modalInstance, trackChangesVisible)->
		$scope.trackChangesVisible = trackChangesVisible
		if ace.require("ace/lib/useragent").isMac
			$scope.ctrl = "Cmd"
		else
			$scope.ctrl = "Ctrl"
		
		$scope.cancel = () ->
			$modalInstance.dismiss()
