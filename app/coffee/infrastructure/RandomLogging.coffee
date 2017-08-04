_ = require('underscore')
metrics = require('metrics-sharelatex')

do trackOpenSockets = ->
	metrics.gauge("http.open-sockets", _.size(require('http').globalAgent.sockets.length), 0.5)
	setTimeout(trackOpenSockets, 1000)
