########################################
#
# company challenges view
#
########################################

########################################
Template.company_challenges.onCreated ->
	this.parameter = new ReactiveDict()
	Session.set "selected_challenge", 0

########################################
Template.company_challenges.helpers
	parameter: () ->
		return Template.instance().parameter

	challenges: () ->
		filter =
			owner_id: Meteor.userId()

		return Challenges.find(filter)

########################################
Template.company_challenges.events
	"change #query":(event)->
		event.preventDefault()
		q = event.target.value
		ins = Template.instance()
		ins.parameter.set "query", q

	"click #add_challenge": () ->
		Meteor.call "add_challenge",
			(err, res) ->
				if err
					sAlert.error("Add challenge error: " + err)


########################################
#
# challenge_preview
#
#########################################

########################################
Template.challenge_preview.helpers
	title: () ->
		if this.title
			return this.title

		return "This challenge does not yet have a title."

	content: () ->
		if this.content
			return this.content

		return "No description available, yet."

	challenge_link: () ->
		return build_url "company_challenge", {challenge_id: this._id}


########################################
#
# challenge
#
########################################

########################################
Template.company_challenge.onCreated ->
	self = this
	self.send_disabled = new ReactiveVar(false)

	self.autorun ->
		id = FlowRouter.getQueryParam("challenge_id")
		if not id
			return
		self.subscribe "my_challenge_by_id", id


########################################
Template.company_challenge.helpers
	challenge: () ->
		id = FlowRouter.getQueryParam("challenge_id")
		return Challenges.findOne id

	send_disabled: () ->
		if Template.instance().send_disabled.get()
			return "disabled"
		return ""

	publish_disabled: () ->
		data = Template.currentData()

		content = get_field_value data, "content", data._id, "Challenges"
		if not content
			return "disabled"

		title = get_field_value data, "title", data._id, "Challenges"
		if not title
			return "disabled"

		published = get_field_value data, "published", data._id, "Challenges"
		if published
			return "disabled"

		return ""

	share_url: ->
		param =
			challenge_id: this._id
		url = build_url "student_solution", param, true
		return url

########################################
Template.company_challenge.events
	"click #icon_download": (e, n)->
		if document.selection
			range = document.body.createTextRange()
			range.moveToElementText(document.getElementById("challenge_url"))
			range.select()

		else if window.getSelection
			range = document.createRange()
			range.selectNodeContents(document.getElementById("challenge_url"))
			selection = window.getSelection()
			selection.removeAllRanges()
			selection.addRange(range)

		return true

	"click #publish": (event)->
		if event.target.attributes.disabled
			return

		Meteor.call "finish_challenge", this._id,
			(err, res) ->
				if err
					sAlert.error("Finish challenge error: " + err)
				if res
					sAlert.success "Challenge published!"


	"click #send": (event, template)->
		if event.target.attributes.disabled
			return

		inst = Template.instance()
		inst.send_disabled.set(true)

		message = template.find("#message").value
		subject = template.find("#subject").value

		Meteor.call "send_message_to_challenge_students", this._id, subject, message,
			(err, res) ->
				inst.send_disabled.set(false)
				if err
					sAlert.error "Send message error: " + err
				if res
					sAlert.success "Message send."


########################################
#
# challenge solutions
#
########################################

########################################
Template.challenge_solutions.onCreated ->
	this.parameter = new ReactiveDict()
	this.parameter.set "challenge_id", FlowRouter.getQueryParam("challenge_id")

########################################
Template.challenge_solutions.helpers
	parameter: () ->
		return Template.instance().parameter

	challenge_solutions: () ->
		filter =
			challenge_id: FlowRouter.getQueryParam("challenge_id")

		return Solutions.find filter

########################################
Template.challenge_solutions.events
	"change #public_only": () ->
		event.preventDefault()
		q = event.target.checked
		ins = Template.instance()
		ins.parameter.set "published", q

	"change #query": (event) ->
		event.preventDefault()
		q = event.target.value
		ins = Template.instance()
		ins.parameter.set "query", q

########################################
#
# challenge solutions
#
########################################

########################################
Template.challenge_solution.onCreated ->
	self = this
	self.reviews_visible = new ReactiveVar(false)

	self.autorun ->
		self.subscribe "user_summary",
			self.data.owner_id,
			self.data.challenge_id

########################################
Template.challenge_solution.helpers
	resume_url: (author_id) ->
		return author_id

	average_rating: () ->
		filter =
			solution_id: this._id
		mod =
			fields:
				rating: 1
		rev = Reviews.find filter, mod
		r = 0.0
		c = 0.0
		rev.forEach (entry) ->
			if entry.rating
				c += 1
				r += parseInt(entry.rating)

		if c == 0
			return "No reviews yet"

		return "Average rating <em>" + (r/c).toFixed(1) + "</em> out of <em>5</em>"

	reviews: () ->
		filter =
			solution_id: this._id

		crs = Reviews.find filter
		if crs.count()
			return crs

		return false

	feedback: (review_id) ->
		filter =
			review_id: review_id
		return Feedback.find filter

	reviews_visible: ->
		return Template.instance().reviews_visible.get()


########################################
Template.challenge_solution.events
	"click #show_reviews": ->
		f = Template.instance().reviews_visible.get()
		Template.instance().reviews_visible.set !f

	"click #reopen": ()->
		data =
			id: this._id

		Modal.show 'reopen_solution', data

	"click #user_info": () ->
		data = UserSummaries.findOne(this.owner_id)
		data["user_id"] = this.owner_id
		Modal.show 'show_student_info', data



##############################################
# publish modal
##############################################

##############################################
Template.reopen_solution.events
	'click #reopen': ->
		self = this

		Meteor.call "reopen_solution", self.id,
			(err, res) ->
				if err
					sAlert.error "Reopen solution error: " + err
				if res
					sAlert.success "Solution reopened!"

