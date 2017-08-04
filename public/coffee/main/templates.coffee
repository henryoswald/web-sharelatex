define [
	"base"
	"services/algolia-search"
], (App) ->

	App.controller "SearchWikiController", ($scope, algoliaSearch, _) ->
		$scope.hits = []

		$scope.clearSearchText = ->
			$scope.searchQueryText = ""
			updateHits []

		$scope.safeApply = (fn)->
			phase = $scope.$root.$$phase
			if(phase == '$apply' || phase == '$digest')
				$scope.$eval(fn)
			else
				$scope.$apply(fn)

		buildHitViewModel = (hit)->
			page_underscored = hit.pageName.replace(/\s/g,'_')
			section_underscored = hit.sectionName.replace(/\s/g,'_')
			content = hit._highlightResult.content.value
			# Replace many new lines
			content = content.replace(/\n\n+/g, "\n\n")
			lines = content.split("\n")
			# Only show the lines that have a highlighted match
			matching_lines = []
			for line in lines
				if !line.match(/^\[edit\]/)
					content += line + "\n"
					if line.match(/<em>/)
						matching_lines.push line
			content = matching_lines.join("\n...\n")
			result =
				name : hit._highlightResult.pageName.value + " - " + hit._highlightResult.sectionName.value
				url :"/learn/#{page_underscored}##{section_underscored}"
				content: content
			return result

		updateHits = (hits)->
			$scope.safeApply ->
				$scope.hits = hits

		$scope.search = ->
			query = $scope.searchQueryText
			if !query? or query.length == 0
				updateHits []
				return

			algoliaSearch.searchWiki query, (err, response)->
				if response.hits.length == 0
					updateHits []
				else
					hits = _.map response.hits, buildHitViewModel
					updateHits hits