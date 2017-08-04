metrics = require('metrics-sharelatex')
Settings = require('settings-sharelatex')
RedisWrapper = require("./RedisWrapper")
rclient = RedisWrapper.client("lock")
logger = require "logger-sharelatex"

module.exports = LockManager =
	LOCK_TEST_INTERVAL: 50 # 50ms between each test of the lock
	MAX_LOCK_WAIT_TIME: 10000 # 10s maximum time to spend trying to get the lock
	REDIS_LOCK_EXPIRY: 30 # seconds. Time until lock auto expires in redis.

	_blockingKey : (key)-> "lock:web:{#{key}}"

	tryLock : (key, callback = (err, isFree)->)->
		rclient.set LockManager._blockingKey(key), "locked", "EX", LockManager.REDIS_LOCK_EXPIRY, "NX", (err, gotLock)->
			return callback(err) if err?
			if gotLock == "OK"
				metrics.inc "lock-not-blocking"
				callback err, true
			else
				metrics.inc "lock-blocking"
				logger.log key: key, redis_response: gotLock, "lock is locked"
				callback err, false

	getLock: (key, callback = (error) ->) ->
		startTime = Date.now()
		do attempt = () ->
			if Date.now() - startTime > LockManager.MAX_LOCK_WAIT_TIME
				return callback(new Error("Timeout"))

			LockManager.tryLock key, (error, gotLock) ->
				return callback(error) if error?
				if gotLock
					callback(null)
				else
					setTimeout attempt, LockManager.LOCK_TEST_INTERVAL

	checkLock: (key, callback = (err, isFree)->)->
		multi = rclient.multi()
		multi.exists LockManager._blockingKey(key)
		multi.exec (err, replys)->
			return callback(err) if err?
			exists = parseInt replys[0]
			if exists == 1
				metrics.inc "lock-blocking"
				callback err, false
			else
				metrics.inc "lock-not-blocking"
				callback err, true

	releaseLock: (key, callback)->
		rclient.del LockManager._blockingKey(key), callback

	
