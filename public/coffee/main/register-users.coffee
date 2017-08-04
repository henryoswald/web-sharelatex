define [
	"base"
], (App) ->
	App.controller "RegisterUsersController", ($scope, queuedHttp) ->
		$scope.users = []

		$scope.inputs =
			emails: ""

		parseEmails = (emailsString)->
			regexBySpaceOrComma = /[\s,]+/
			emails = emailsString.split(regexBySpaceOrComma)
			emails = _.map emails, (email)->
				email = email.trim()
			emails = _.select emails, (email)->
				email.indexOf("@") != -1
			return emails

		$scope.registerUsers = () ->
			emails = parseEmails($scope.inputs.emails)
			$scope.error = false
			for email in emails
				queuedHttp
					.post("/admin/register", {
						email: email,
						_csrf: window.csrfToken
					})
					.then (response) ->
						{ data } = response
						user = data
						$scope.users.push user
						$scope.inputs.emails = ""
					.catch () ->
						$scope.error = true