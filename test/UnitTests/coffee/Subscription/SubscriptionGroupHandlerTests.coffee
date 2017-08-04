SandboxedModule = require('sandboxed-module')
should = require('chai').should()
sinon = require 'sinon'
assert = require("chai").assert
modulePath = "../../../../app/js/Features/Subscription/SubscriptionGroupHandler"


describe "SubscriptionGroupHandler", ->

	beforeEach ->
		@adminUser_id = "12321"
		@newEmail = "bob@smith.com"
		@user_id = "3121321"
		@email = "jim@example.com"
		@user = {_id:@user_id, email:@newEmail}
		@subscription_id = "31DSd1123D"

		@subscription =
			admin_id:@adminUser_id
			_id:@subscription_id

		@SubscriptionLocator = 
			getUsersSubscription: sinon.stub()
			getSubscriptionByMemberIdAndId: sinon.stub()
			getSubscription: sinon.stub()

		@UserCreator = 
			getUserOrCreateHoldingAccount: sinon.stub().callsArgWith(1, null, @user)

		@SubscriptionUpdater =
			addUserToGroup: sinon.stub().callsArgWith(2)
			removeUserFromGroup: sinon.stub().callsArgWith(2)
			addEmailInviteToGroup: sinon.stub().callsArgWith(2)
			removeEmailInviteFromGroup: sinon.stub().callsArgWith(2)

		@UserLocator =
			findById: sinon.stub()
			findByEmail: sinon.stub()

		@LimitationsManager =
			hasGroupMembersLimitReached: sinon.stub()

		@OneTimeTokenHandler =
			getValueFromTokenAndExpire:sinon.stub()
			getNewToken:sinon.stub()

		@EmailHandler =
			sendEmail:sinon.stub()

		@settings = 
			siteUrl:"http://www.sharelatex.com"

		@readStub = sinon.stub()
		@NotificationsBuilder =
			groupPlan: sinon.stub().returns({read:@readStub})

		@Handler = SandboxedModule.require modulePath, requires:
			"logger-sharelatex": log:->
			"../User/UserCreator": @UserCreator
			"./SubscriptionUpdater": @SubscriptionUpdater
			"./SubscriptionLocator": @SubscriptionLocator
			"../User/UserLocator": @UserLocator
			"./LimitationsManager": @LimitationsManager
			"../Security/OneTimeTokenHandler":@OneTimeTokenHandler
			"../Email/EmailHandler":@EmailHandler
			"settings-sharelatex":@settings
			"../Notifications/NotificationsBuilder": @NotificationsBuilder
			"logger-sharelatex": 
				err:->
				log:->
				warn:->


	describe "addUserToGroup", ->
		beforeEach ->
			@LimitationsManager.hasGroupMembersLimitReached.callsArgWith(1, null, false, @subscription)
			@UserLocator.findByEmail.callsArgWith(1, null, @user)
			
		it "should find the user", (done)->
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				@UserLocator.findByEmail.calledWith(@newEmail).should.equal true
				done()

		it "should add the user to the group", (done)->
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				@SubscriptionUpdater.addUserToGroup.calledWith(@adminUser_id, @user._id).should.equal true
				done()
				
		it "should not add the user to the group if the limit has been reached", (done)->
			@LimitationsManager.hasGroupMembersLimitReached.callsArgWith(1, null, true, @subscription)
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				@SubscriptionUpdater.addUserToGroup.called.should.equal false
				done()

		it "should return error that limit has been reached", (done)->
			@LimitationsManager.hasGroupMembersLimitReached.callsArgWith(1, null, true, @subscription)
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				err.limitReached.should.equal true
				done()

		it "should mark any notification as read if it is part of a licence", (done)->
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				@NotificationsBuilder.groupPlan.calledWith(@user, {subscription_id:@subscription._id}).should.equal true
				@readStub.called.should.equal true
				done()
		
		it "should add an email invite if no user is found", (done) ->
			@UserLocator.findByEmail.callsArgWith(1, null, null)
			@Handler.addUserToGroup @adminUser_id, @newEmail, (err)=>
				@SubscriptionUpdater.addEmailInviteToGroup.calledWith(@adminUser_id, @newEmail).should.equal true
				done()

	describe "removeUserFromGroup", ->

		it "should call the subscription updater to remove the user", (done)->
			@Handler.removeUserFromGroup @adminUser_id, @user._id, (err)=>
				@SubscriptionUpdater.removeUserFromGroup.calledWith(@adminUser_id, @user._id).should.equal true
				done()


	describe "getPopulatedListOfMembers", ->
		beforeEach ->
			@subscription = {}
			@SubscriptionLocator.getUsersSubscription.callsArgWith(1, null, @subscription)
			@UserLocator.findById.callsArgWith(1, null, {_id:"31232"})

		it "should locate the subscription", (done)->
			@UserLocator.findById.callsArgWith(1, null, {_id:"31232"})
			@Handler.getPopulatedListOfMembers @adminUser_id, (err, users)=>
				@SubscriptionLocator.getUsersSubscription.calledWith(@adminUser_id).should.equal true
				done()

		it "should get the users by id", (done)->
			@UserLocator.findById.callsArgWith(1, null, {_id:"31232"})
			@subscription.member_ids = ["1234", "342432", "312312"]
			@Handler.getPopulatedListOfMembers @adminUser_id, (err, users)=>
				@UserLocator.findById.calledWith(@subscription.member_ids[0]).should.equal true
				@UserLocator.findById.calledWith(@subscription.member_ids[1]).should.equal true
				@UserLocator.findById.calledWith(@subscription.member_ids[2]).should.equal true
				users.length.should.equal @subscription.member_ids.length
				done()

		it "should just return the id if the user can not be found as they may have deleted their account", (done)->
			@UserLocator.findById.callsArgWith(1)
			@subscription.member_ids = ["1234", "342432", "312312"]
			@Handler.getPopulatedListOfMembers @adminUser_id, (err, users)=>
				assert.deepEqual users[0], {_id:@subscription.member_ids[0]}
				assert.deepEqual users[1], {_id:@subscription.member_ids[1]}
				assert.deepEqual users[2], {_id:@subscription.member_ids[2]}
				done()
		
		it "should return any invited users", (done) ->
			@subscription.invited_emails = ["jo@example.com", "charlie@example.com"]
			@Handler.getPopulatedListOfMembers @adminUser_id, (err, users)=>
				users[0].email.should.equal "jo@example.com"
				users[0].holdingAccount.should.equal true
				users[1].email.should.equal "charlie@example.com"
				users[1].holdingAccount.should.equal true
				users.length.should.equal @subscription.invited_emails.length
				done()

	describe "isUserPartOfGroup", ->
		beforeEach ->
			@subscription_id = "123ed13123"

		it "should return true when user is part of subscription", (done)->
			@SubscriptionLocator.getSubscriptionByMemberIdAndId.callsArgWith(2, null, {_id:@subscription_id})
			@Handler.isUserPartOfGroup @user_id, @subscription_id, (err, partOfGroup)->
				partOfGroup.should.equal true
				done()

		it "should return false when no subscription is found", (done)->
			@SubscriptionLocator.getSubscriptionByMemberIdAndId.callsArgWith(2, null)
			@Handler.isUserPartOfGroup @user_id, @subscription_id, (err, partOfGroup)->
				partOfGroup.should.equal false
				done()


	describe "sendVerificationEmail", ->
		beforeEach ->
			@token = "secret token"
			@subscription_id = "123ed13123"
			@licenceName = "great licnece"
			@email = "bob@smith.com"
			@OneTimeTokenHandler.getNewToken.callsArgWith(2, null, @token)
			@EmailHandler.sendEmail.callsArgWith(2)

		it "should put a one time token into the email", (done)->
			@Handler.sendVerificationEmail @subscription_id, @licenceName, @email, (err)=>
				emailOpts = @EmailHandler.sendEmail.args[0][1]
				emailOpts.completeJoinUrl.should.equal "#{@settings.siteUrl}/user/subscription/#{@subscription_id}/group/complete-join?token=#{@token}"
				emailOpts.to.should.equal @email
				emailOpts.group_name.should.equal @licenceName
				done()

	describe "processGroupVerification", ->
		beforeEach ->
			@token = "31dDAd2Da"
			@SubscriptionLocator.getSubscription.callsArgWith(1, null, @subscription)
			@Handler.addUserToGroup = sinon.stub().callsArgWith(2)

		it "should addUserToGroup", (done)->
			@OneTimeTokenHandler.getValueFromTokenAndExpire.callsArgWith(1, null, @subscription_id)
			@Handler.processGroupVerification @email, @subscription_id, @token, (err)=>
				@Handler.addUserToGroup.calledWith(@adminUser_id, @email).should.equal true
				done()

		it "should return token_not_found error if it couldn't get the token", (done)->
			@OneTimeTokenHandler.getValueFromTokenAndExpire.callsArgWith(1)
			@Handler.processGroupVerification @email, @subscription_id, @token, (err)=>
				err.should.equal "token_not_found"
				done()

	describe "convertEmailInvitesToMemberships", ->
		beforeEach ->
			@SubscriptionLocator.getGroupsWithEmailInvite = sinon.stub().yields(null, @groups = [{ admin_id: "group-1" }, { admin_id: "group-2" }])

		it "should get groups with the email address invited to", (done) ->
			@Handler.convertEmailInvitesToMemberships @email, @user_id, (err) =>
				@SubscriptionLocator.getGroupsWithEmailInvite.calledWith(@email).should.equal true
				done()
		
		it "should remove the email from each group", (done) ->
			@Handler.convertEmailInvitesToMemberships @email, @user_id, (err) =>
				for group in @groups
					@SubscriptionUpdater.removeEmailInviteFromGroup
						.calledWith(group.admin_id, @email)
						.should.equal true
				done()
		
		it "should add the user to each group", (done) ->
			@Handler.convertEmailInvitesToMemberships @email, @user_id, (err) =>
				for group in @groups
					@SubscriptionUpdater.addUserToGroup
						.calledWith(group.admin_id, @user_id)
						.should.equal true
				done()

