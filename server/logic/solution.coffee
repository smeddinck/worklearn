###############################################
@gen_solution = (challenge, user) ->
	filter =
		challenge_id: challenge._id
		owner_id: user._id

	solution = Solutions.findOne filter
	if solution
		return solution._id

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

	s_id = store_document_unprotected Solutions, solution
	msg = "Solution (" + s_id + ") generated by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return s_id


###############################################
@finish_solution = (solution, user) ->
	if solution.published
		return solution._id

	requested = num_requested_reviews solution
	provided = num_provided_reviews solution
	credits = provided - requested

	if credits < 0
		msg = "You need to finish your pending reviews."
		msg += "To publish a new solution."
		msg += "Go to My Challenges and finish open challenges."
		throw new Meteor.Error "no-credits", msg

	modify_field_unprotected Solutions, solution._id, "published", true
	solution = Solutions.findOne solution._id

	request_review solution, user

	msg = "Solution (" + solution.id + ") published by: " + get_user_mail user
	log_event msg, event_logic, event_info

	#TODO: inform people on the waiting list for reviews.

	return solution._id


###############################################
@reopen_solution = (solution, user) ->
	if !solution.published
		return solution._id

	# we can reopen a solution when:
	# There are no published reviews

	filter =
		solution_id: solution._id
		published: false

	mod =
		fields:
			assigned: 1
			modified: 1

	reviews = Reviews.find(filter, mod).fetch()

	# There are no assigned reviews that
	# have been touched in the last 24 hours
	for r in reviews
		if r.assigned == false
			continue
		if r.modified > new Date((new Date())-1000*60*60*24)
			continue

		throw new Meteor.Error "in-progress", "The Solution already has reviews."

	modify_field_unprotected Solutions, solution._id, "published", false

	Reviews.remove filter
	Feedback.remove filter

	msg = "Solution (" + solution.id + ") reopened by: " + get_user_mail user
	log_event msg, event_logic, event_info

	return solution._id

