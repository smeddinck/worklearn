########################################
#
# student review
#
########################################

########################################
# review list
########################################

########################################
Template.student_reviews.onCreated ->
	this.searching = new ReactiveVar(false)

########################################
Template.student_reviews.helpers
	reviews: () ->
		filter =
			type_identifier: "review"

		return Responses.find(filter)

	searching: () ->
		Template.instance().searching.get()

########################################
Template.student_reviews.events
	"click #find_review": () ->
		inst = Template.instance()
		inst.searching.set true

		Meteor.call "find_review", this._id,
			(err, res) ->
				inst.searching.set false
				if err
					sAlert.error err
				if res
					sAlert.success "Review received!"


########################################
# review preview
########################################

########################################
Template.student_review_preview.onCreated ->
	self = this
	self.autorun () ->
		filter =
			_id: self.data.challenge_id

		self.subscribe "responses", filter, false, true, "student_review_preview: challenge"


########################################
Template.student_review_preview.helpers
	challenge: () ->
		return Responses.findOne this.challenge_id


########################################
Template.student_review_preview.events
	"click #student_review": () ->
		Session.set "current_data", Responses.findOne this._id
		Session.set "student_template", "student_review"


########################################
# review editor
########################################

########################################
Template.student_review.onCreated ->
	self = this

	self.autorun () ->
		filter =
			_id: self.data.parent_id
		self.subscribe "responses", filter, false, false, "student_solution"

		filter =
			_id: self.data.challenge_id
		self.subscribe "responses", filter, false, false, "student_solution"


########################################
Template.student_review.helpers
	challenge: () ->
		return Responses.findOne this.challenge_id

	solution: () ->
		filter =
			_id: this.parent_id
		return Responses.findOne filter

	rating: () ->
		data = Template.currentData()
		rating = get_field_value data, "rating", data._id, "Responses"
		return rating

	publish_disabled: () ->
		data = Template.currentData()

		content = get_field_value data, "content", data._id, "Responses"
		if not content
			return "disabled"

		rating = get_field_value data, "rating", data._id, "Responses"
		if not rating
			return "disabled"

		return ""


########################################
Template.student_review.events
	"click #publish":()->
		Modal.show('publish_review', this)

##############################################
# publish modal
##############################################

##############################################
Template.publish_review.events
	'click #publish': ->
		Meteor.call "set_field", "Responses", this._id, "visible_to", "anonymous",
			(err, res) ->
				if err
					sAlert.error(err)
				if res
					sAlert.success "Review published!"


