define [
	"ide/binary-files/controllers/BinaryFileController"
], () ->
	class BinaryFilesManager
		constructor: (@ide, @$scope) ->
			@$scope.$on "entity:selected", (event, entity) =>
				if (@$scope.ui.view != "track-changes" and entity.type == "file")
					@openFile(entity)

		openFile: (file) ->
			@$scope.ui.view = "file"
			@$scope.openFile = null
			@$scope.$apply()
			window.setTimeout(
				() =>
					@$scope.openFile = file
					@$scope.$apply()
				, 0
				, this
			)
