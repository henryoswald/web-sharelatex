define [
	"base"
], (App) ->
	App.factory "settings", ["ide", "event_tracking", (ide, event_tracking) ->
		return {
			saveSettings: (data) ->
				# Tracking code.
				for key in Object.keys(data)
					changedSetting = key
					changedSettingVal = data[key]
					event_tracking.sendMB "setting-changed", { changedSetting, changedSettingVal }
				# End of tracking code.
				
				data._csrf = window.csrfToken
				return ide.$http.post "/user/settings", data

			saveProjectSettings: (data) ->
				# Tracking code.
				for key in Object.keys(data)
					changedSetting = key
					changedSettingVal = data[key]
					event_tracking.sendMB "project-setting-changed", { changedSetting, changedSettingVal}
				# End of tracking code.
				
				data._csrf = window.csrfToken
				return ide.$http.post "/project/#{ide.project_id}/settings", data

			saveProjectAdminSettings: (data) ->
				# Tracking code.
				for key in Object.keys(data)
					changedSetting = key
					changedSettingVal = data[key]
					event_tracking.sendMB "project-admin-setting-changed", { changedSetting, changedSettingVal }
				# End of tracking code.
				
				data._csrf = window.csrfToken
				return ide.$http.post "/project/#{ide.project_id}/settings/admin", data
		}
	]