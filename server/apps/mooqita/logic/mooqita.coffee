###############################################
_num_requested_reviews  = (solution) ->
	if solution
		requester_id = solution.owner_id
	else
		requester_id = this.userId

	filter =
		requester_id: requester_id

	if solution
		filter.challenge_id = solution.challenge_id

	res = ReviewRequests.find filter
	return  res.count()

###############################################
_num_provided_reviews = (solution) ->
	if solution
		requester_id = solution.owner_id
	else
		requester_id = this.userId

	filter =
		provider_id: requester_id
		review_done: true

	if solution
		filter.challenge_id = solution.challenge_id

	res = ReviewRequests.find filter
	return  res.count()


###############################################
@gen_challenge = (user) ->
	challenge =
		owner_id: user._id
		num_reviews: 2

	res = store_document Challenges, challenge
	msg = "Challenge (" + challenge._id + ") generated by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return res


###############################################
@finish_challenge = (challenge, user) ->
	modify_field_unprotected Challenges, challenge._id, "published", true
	modify_field_unprotected Challenges, challenge._id, "visible_to", "anonymous"

	#TODO: inform last round participants

	msg = "Challenge (" + challenge._id + ") published by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return res


###############################################
@gen_solution = (challenge, user) ->
	solution =
		name: "Solution: " + challenge.title
		index: 1
		owner_id: user._id
		parent_id: challenge._id
		view_order: 1
		group_name: ""
		template_id: "solution"
		challenge_id: challenge._id
		published: false

	res = store_document Solutions, solution
	msg = "Solution (" + res + ") generated by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return res


###############################################
@finish_solution = (solution, user) ->
	if solution.published
		throw new Meteor.Error "Solution: " + solution._id + " is already published"

	requested = _num_requested_reviews solution
	provided = _num_provided_reviews solution
	credits = provided - requested

	if credits < 0
		msg = "You need to finish your pending reviews."
		msg += "To publish a new solution."
		msg += "Go to My Challenges and finish open challenges."
		throw new Meteor.Error "no-credits", msg

	modify_field_unprotected Solutions, solution._id, "published", true
	solution = Solutions.findOne solution._id

	#TODO: inform people on the waiting list for reviews.

	request_review solution, user

	msg = "Solution (" + solution.id + ") published by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return solution._id


###############################################
@reopen_solution = (solution, user) ->
	filter =
		solution_id: solution._id

	requests = ReviewRequests.find(filter).fetch()

	for r in requests
		if r.review_id
			throw new Meteor.Error "in-progress", "The Solution already has reviews."

	n = ReviewRequests.remove filter

	mod =
		$set:
			published: false
	Solutions.update solution._id, mod

	msg = "Solution (" + solution.id + ") reopened by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return n


###############################################
@request_review = (solution, user) ->
	requested = _num_requested_reviews solution
	provided = _num_provided_reviews solution
	credits = provided - requested

	if not Roles.userIsInRole user, "challenge_designer"
		if credits < 0
			throw new Meteor.Error "User needs more credits to request reviews."

	#WordPOS = require("wordpos")
	#wordpos = new WordPOS()
	#text_index = wordpos.parse challenge.content

	rr =
		challenge_id: solution.challenge_id
		solution_id: solution._id
		review_id: ""
		review_done: false
		feedback_id: ""
		feedback_done: false
		provider_id: ""
		requester_id: user._id
		under_review_since: new Date((new Date())-1000*60*60*25)
#		text_index: text_index.join().toLowerCase()

	rr_id = ReviewRequests.insert rr
	msg = "Solution (" + solution.id + ") review requested by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return rr_id


###############################################
@find_solution_to_review = (user, challenge=null) ->
	#solution must have unsatisfied review requests
	#solution owner must have enough credit to receive/request reviews
	#solution must be in the realm of the student
	#solution must be visible to others
	#solution is not owned by the reviewer

#	corpus = collect_keywords user._id

#	WordPOS = require("wordpos")
#	wordpos = new WordPOS()
#	text_index = wordpos.parse corpus

	filter =
		under_review_since:
			$lt: new Date((new Date())-1000*60*60*24)
		review_done: false
		requester_id:
			$ne: user._id
#		$text:
#			$search: text_index.join().toLowerCase()

	mod =
		sort:
			under_review_since: 1

	if challenge
		filter.challenge_id = challenge._id

	rr = ReviewRequests.findOne filter, mod

	if not rr
		throw new Meteor.Error "no-solution", "There are no solutions to review at the moment."

	if not challenge
		challenge = Challenges.findOne rr.challenge_id

		if not challenge
			throw new Meteor.Error "no-challenge", "challenge not found"

	solution = Solutions.findOne rr.solution_id
	if not solution
		throw new Meteor.Error "no-solution","solution not found"

	return rr


###############################################
@gen_review = (challenge, solution, user) ->
	if solution
		filter =
			solution_id: solution._id
			review_done: false
		review_request = ReviewRequests.findOne filter
	else if challenge
		review_request = find_solution_to_review user, challenge
	else
		review_request = find_solution_to_review user

	if review_request.review_id
		review = Reviews.findOne review_request.review_id
		send_review_timeout_message review
		Reviews.remove review_request.review_id

	if review_request.feedback_id
		Feedback.remove review_request.feedback_id

	review_id = Random.id()
	solution = Solutions.findOne review_request.solution_id
	challenge = Challenges.findOne review_request.challenge_id

	review =
		_id: review_id
		index: 1
		owner_id: user._id
		parent_id: solution._id
		solution_id: solution._id
		challenge_id: challenge._id
		view_order: 1
		group_name: ""
		visible_to: "owner"
		template_id: "review"

	feedback =
		index: 1
		owner_id: solution.owner_id
		parent_id: review_id
		review_id: review_id
		solution_id: solution._id
		challenge_id: challenge._id
		view_order: 1
		group_name: ""
		visible_to: "owner"
		template_id: "feedback"

	r_id = store_document Reviews, review
	f_id = store_document Feedback, feedback

	modify_field_unprotected ReviewRequests,
		review_request._id, "under_review_since", new Date()

	modify_field_unprotected ReviewRequests,
		review_request._id, "provider_id", user._id

	modify_field_unprotected ReviewRequests,
		review_request._id, "review_id", r_id

	modify_field_unprotected ReviewRequests,
		review_request._id, "feedback_id", f_id

	res =
		review_id: r_id
		solution_id: solution._id
		challenge_id: challenge._id

	msg = "Review (" + r_id + ") review generated by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return res


###############################################
@finish_review = (review, user) ->
	if not review.rating
		throw new Meteor.Error "Review: " + review._id + " Does not have a rating."

	if review.published
		throw new Meteor.Error "Review: " + review._id + " is already published"

	filter =
		review_id: review._id
	rr = ReviewRequests.findOne filter

	modify_field_unprotected Reviews, review._id, "published", true
	modify_field_unprotected ReviewRequests, rr._id, "review_done", true
	modify_field_unprotected ReviewRequests, rr._id, "review_finished", new Date()

	send_review_message review

	# Find the solution the review provider submitted.
	# The solution has to be submitted to the same challenge
	# as the solution in the review.
	filter =
		requester_id: review.owner_id
		challenge_id: review.challenge_id

	request = ReviewRequests.findOne filter
	if not request
		if Roles.userIsInRole review.owner_id, "tutor"
			return review._id

		throw new Meteor.Error "A non tutor provided a review without a solution."

	solution = Solutions.findOne request.solution_id
	challenge = Challenges.findOne review.challenge_id

	provided = _num_provided_reviews solution
	required = 	challenge.num_reviews

	r_owner = Meteor.users.findOne review.owner_id

	if solution.published
		if Roles.userIsInRole solution.owner_id, "challenge_designer"
			request_review solution, r_owner
		else if required > provided
			request_review solution, r_owner

	msg = "Review (" + review._id + ") review finished by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return review._id


###############################################
@finish_feedback = (feedback, user) ->
	if not feedback.rating
		throw new Meteor.Error "Feedback: " + feedback._id + " Does not have a rating."

	if feedback.published
		throw new Meteor.Error "Feedback: " + feedback._id + " is already published."

	filter =
		feedback_id: feedback._id
	rr = ReviewRequests.findOne filter

	modify_field_unprotected Feedback, feedback._id, "published", true
	modify_field_unprotected ReviewRequests, rr._id, "feedback_done", true
	modify_field_unprotected ReviewRequests, rr._id, "feedback_finished", new Date()

	feedback = Feedback.findOne feedback._id
	send_feedback_message feedback

	msg = "Feedback (" + feedback._id + ") feedback finished by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return feedback._id


