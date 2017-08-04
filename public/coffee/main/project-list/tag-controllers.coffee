define [
	"base"
], (App) ->

	App.controller "TagListController", ($scope, $modal) ->
		$scope.filterProjects = (filter = "all") ->
			$scope._clearTags()
			$scope.setFilter(filter)

		$scope._clearTags = () ->
			for tag in $scope.tags
				tag.selected = false
			
		$scope.selectTag = (tag) ->
			$scope._clearTags()
			tag.selected = true
			$scope.setFilter("tag")

		$scope.selectUntagged = () ->
			$scope._clearTags()
			$scope.setFilter("untagged")

		$scope.deleteTag = (tag) ->
			modalInstance = $modal.open(
				templateUrl: "deleteTagModalTemplate"
				controller: "DeleteTagModalController"
				resolve:
					tag: () -> tag
			)
			modalInstance.result.then () ->
				# Remove tag from projects
				for project in $scope.projects
					project.tags ||= []
					index = project.tags.indexOf tag
					if index > -1
						project.tags.splice(index, 1)
				# Remove tag
				$scope.tags = $scope.tags.filter (t) -> t != tag
		
		$scope.renameTag = (tag) ->
			modalInstance = $modal.open(
				templateUrl: "renameTagModalTemplate"
				controller: "RenameTagModalController"
				resolve:
					tag: () -> tag
					existing_tags: () -> $scope.tags
			)
			modalInstance.result.then (new_name) ->
				tag.name = new_name

	App.controller "TagDropdownItemController", ($scope) ->
		$scope.recalculateProjectsInTag = () ->
			$scope.areSelectedProjectsInTag = false
			for project_id in $scope.getSelectedProjectIds()
				if project_id in $scope.tag.project_ids
					$scope.areSelectedProjectsInTag = true
				else
					partialSelection = true

			if $scope.areSelectedProjectsInTag and partialSelection
				$scope.areSelectedProjectsInTag = "partial"

		$scope.addOrRemoveProjectsFromTag = () ->
			if $scope.areSelectedProjectsInTag == true
				$scope.removeSelectedProjectsFromTag($scope.tag)
				$scope.areSelectedProjectsInTag = false
			else if $scope.areSelectedProjectsInTag == false or $scope.areSelectedProjectsInTag == "partial"
				$scope.addSelectedProjectsToTag($scope.tag)
				$scope.areSelectedProjectsInTag = true

		$scope.$watch "selectedProjects", () ->
			$scope.recalculateProjectsInTag()
		$scope.recalculateProjectsInTag()
	
	App.controller 'NewTagModalController', ($scope, $modalInstance, $timeout, $http) ->
		$scope.inputs = 
			newTagName: ""
		
		$scope.state =
			inflight: false
			error: false

		$modalInstance.opened.then () ->
			$timeout () ->
				$scope.$broadcast "open"
			, 200

		$scope.create = () ->
			name = $scope.inputs.newTagName
			$scope.state.inflight = true
			$scope.state.error = false
			$http
				.post "/tag", {
					_csrf: window.csrfToken,
					name: name
				}
				.then (response) ->
					{ data } = response
					$scope.state.inflight = false
					$modalInstance.close(data)
				.catch () ->
					$scope.state.inflight = false
					$scope.state.error = true

		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')
	
	App.controller 'RenameTagModalController', ($scope, $modalInstance, $timeout, $http, tag, existing_tags) ->
		$scope.inputs = 
			tagName: tag.name
		
		$scope.state =
			inflight: false
			error: false

		$modalInstance.opened.then () ->
			$timeout () ->
				$scope.$broadcast "open"
			, 200

		$scope.rename = () ->
			name = $scope.inputs.tagName
			$scope.state.inflight = true
			$scope.state.error = false
			$http
				.post "/tag/#{tag._id}/rename", {
					_csrf: window.csrfToken,
					name: name
				}
				.then () ->
					$scope.state.inflight = false
					$modalInstance.close(name)
				.catch () ->
					$scope.state.inflight = false
					$scope.state.error = true

		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')
		
	App.controller 'DeleteTagModalController', ($scope, $modalInstance, $http, tag) ->
		$scope.tag = tag
		$scope.state =
			inflight: false
			error: false
		
		$scope.delete = () ->
			$scope.state.inflight = true
			$scope.state.error = false
			$http({
				method: "DELETE"
				url: "/tag/#{tag._id}"
				headers:
					"X-CSRF-Token": window.csrfToken
			})
				.then () ->
					$scope.state.inflight = false
					$modalInstance.close()
				.catch () ->
					$scope.state.inflight = false
					$scope.state.error = true
		
		$scope.cancel = () ->
			$modalInstance.dismiss('cancel')
