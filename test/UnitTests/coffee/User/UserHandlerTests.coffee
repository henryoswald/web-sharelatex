sinon = require('sinon')
chai = require('chai')
should = chai.should()
modulePath = "../../../../app/js/Features/User/UserHandler.js"
SandboxedModule = require('sandboxed-module')

describe "UserHandler", ->

	beforeEach ->
		@user = 
			_id:"12390i"
			email: "bob@bob.com"
			remove: sinon.stub().callsArgWith(0)

		@licence = 
			subscription_id: 12323434
		@SubscriptionDomainHandler =
			getLicenceUserCanJoin: sinon.stub()

		@SubscriptionGroupHandler =
			isUserPartOfGroup:sinon.stub()
			convertEmailInvitesToMemberships: sinon.stub().callsArgWith(2)
		@createStub = sinon.stub().callsArgWith(0)
		@NotificationsBuilder = 
			groupPlan:sinon.stub().returns({create:@createStub})

		@UserHandler = SandboxedModule.require modulePath, requires:
			"logger-sharelatex": @logger = { log: sinon.stub() }
			"../Notifications/NotificationsBuilder":@NotificationsBuilder
			"../Subscription/SubscriptionDomainHandler":@SubscriptionDomainHandler
			"../Subscription/SubscriptionGroupHandler":@SubscriptionGroupHandler

	describe "populateGroupLicenceInvite", ->
		describe "no licence", ->
			beforeEach (done)->
				@SubscriptionDomainHandler.getLicenceUserCanJoin.returns()
				@UserHandler.populateGroupLicenceInvite @user, done
			
			it "should call convertEmailInvitesToMemberships", ->
				@SubscriptionGroupHandler.convertEmailInvitesToMemberships
					.calledWith(@user.email, @user._id)
					.should.equal true

			it "should not call NotificationsBuilder", (done)->
				@NotificationsBuilder.groupPlan.called.should.equal false
				done()

			it "should not call isUserPartOfGroup", (done)->
				@SubscriptionGroupHandler.isUserPartOfGroup.called.should.equal false
				done()

		describe "with matching licence user is not in", ->
			beforeEach (done)->
				@SubscriptionDomainHandler.getLicenceUserCanJoin.returns(@licence)
				@SubscriptionGroupHandler.isUserPartOfGroup.callsArgWith(2, null, false)
				@UserHandler.populateGroupLicenceInvite @user, done

			it "should create notifcation", (done)->
				@NotificationsBuilder.groupPlan.calledWith(@user, @licence).should.equal true
				done()
			
			it "should call convertEmailInvitesToMemberships", ->
				@SubscriptionGroupHandler.convertEmailInvitesToMemberships
					.calledWith(@user.email, @user._id)
					.should.equal true

		describe "with matching licence user is already in", ->
			beforeEach (done)->
				@SubscriptionDomainHandler.getLicenceUserCanJoin.returns(@licence)
				@SubscriptionGroupHandler.isUserPartOfGroup.callsArgWith(2, null, true)
				@UserHandler.populateGroupLicenceInvite @user, done

			it "should create notifcation", (done)->
				@NotificationsBuilder.groupPlan.called.should.equal false
				done()
			
			it "should call convertEmailInvitesToMemberships", ->
				@SubscriptionGroupHandler.convertEmailInvitesToMemberships
					.calledWith(@user.email, @user._id)
					.should.equal true