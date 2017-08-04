define [
	"base"
], (App) ->
	App.controller "BinaryFileController", ["$scope", "$rootScope", "$http", "$timeout", ($scope, $rootScope, $http, $timeout) ->

		TWO_MEGABYTES = 2 * 1024 * 1024

		$scope.bibtexPreview =
			loading: false
			shouldShowDots: false
			error: false
			data: null

		# Callback fired when the `img` tag fails to load,
		# `failedLoad` used to show the "No Preview" message
		$scope.failedLoad = false
		window.sl_binaryFilePreviewError = () =>
			$scope.failedLoad = true
			$scope.$apply()

		# Callback fired when the `img` tag is done loading,
		# `imgLoaded` is used to show the spinner gif while loading
		$scope.imgLoaded = false
		window.sl_binaryFilePreviewLoaded = () =>
			$scope.imgLoaded = true
			$scope.$apply()

		$scope.extension = (file) ->
			return file.name.split(".").pop()?.toLowerCase()

		$scope.loadBibtexFilePreview = () ->
			url = "/project/#{project_id}/file/#{$scope.openFile.id}?range=0-#{TWO_MEGABYTES}"
			$scope.bibtexPreview.loading = true
			$scope.bibtexPreview.shouldShowDots = false
			$scope.$apply()
			$http.get(url)
				.then (response) ->
					{ data } = response
					$scope.bibtexPreview.loading = false
					$scope.bibtexPreview.error = false
					# show dots when payload is closs to cutoff
					if data.length >= (TWO_MEGABYTES - 200)
						$scope.bibtexPreview.shouldShowDots = true
					try
						# remove last partial line
						data = data.replace(/\n.*$/, '')
					finally
						$scope.bibtexPreview.data = data
					$timeout($scope.setHeight, 0)
				.catch () ->
					$scope.bibtexPreview.error = true
					$scope.bibtexPreview.loading = false

		$scope.setHeight = () ->
			# Behold, a ghastly hack
			guide = document.querySelector('.file-tree-inner')
			table_wrap = document.querySelector('.bib-preview .scroll-container')
			if table_wrap
				desired_height = guide.offsetHeight - 44
				if table_wrap.offsetHeight > desired_height
					table_wrap.style.height = desired_height + 'px'
					table_wrap.style['max-height'] = desired_height + 'px'

		$scope.loadBibtexIfRequired = () ->
			if $scope.extension($scope.openFile) == 'bib'
				$scope.bibtexPreview.data = null
				$scope.loadBibtexFilePreview()

		$scope.loadBibtexIfRequired()

	]
