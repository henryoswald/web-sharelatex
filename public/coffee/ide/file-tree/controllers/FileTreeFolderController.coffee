define [
	"base"
], (App) ->
	App.controller "FileTreeFolderController", ($scope, ide, $modal, localStorage) ->
		$scope.expanded = localStorage("folder.#{$scope.entity.id}.expanded") or false

		$scope.toggleExpanded = () ->
			$scope.expanded = !$scope.expanded
			localStorage("folder.#{$scope.entity.id}.expanded", $scope.expanded)

		$scope.onDrop = (events, ui) ->
			if ide.fileTreeManager.multiSelectedCount()
				entities = ide.fileTreeManager.getMultiSelectedEntityChildNodes() 
			else
				entities = [$(ui.draggable).scope().entity]
			for dropped_entity in entities
				ide.fileTreeManager.moveEntity(dropped_entity, $scope.entity)
			$scope.$digest()
			# clear highlight explicitly
			$('.file-tree-inner .droppable-hover').removeClass('droppable-hover')

		$scope.orderByFoldersFirst = (entity) ->
			# We need this here as well as in FileTreeController
			# since the file-entity diretive creates a new scope
			# that doesn't inherit from previous scopes.
			return '0' if entity?.type == "folder"
			return '1'

		$scope.openNewDocModal = () ->
			$modal.open(
				templateUrl: "newDocModalTemplate"
				controller:  "NewDocModalController"
				resolve: {
					parent_folder: () -> $scope.entity
				}
			)

		$scope.openNewFolderModal = () ->
			$modal.open(
				templateUrl: "newFolderModalTemplate"
				controller:  "NewFolderModalController"
				resolve: {
					parent_folder: () -> $scope.entity
				}
			)

		$scope.openUploadFileModal = () ->
			$scope.project_id = ide.project_id
			$modal.open(
				templateUrl: "uploadFileModalTemplate"
				controller:  "UploadFileModalController"
				scope: $scope
				resolve: {
					parent_folder: () -> $scope.entity
				}
			)
