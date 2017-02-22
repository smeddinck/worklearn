################################################################
#
# Markus 1/23/2017
#
################################################################

################################################################
Meteor.methods
	add_post: (group_name) ->
		check group_name, String

		user = Meteor.user()

		if not user
			throw new Meteor.Error('Not permitted.')

		if !Roles.userIsInRole(user._id, 'editor')
			throw new Meteor.Error('Not permitted.')

		post =
			template: "post"
			post_group: group_name
			owner_id: Meteor.userId()
			view_order: 0
			pub_year: 0

		Posts.insert post

	set_post_field: (collection, item_id, field, data, type)->
		modify_field('Posts', item_id, field, data)

	set_post_visibility: (collection, item_id, field, data, type) ->
		check item_id, String
		check data, Match.OneOf(String, [String])

		if typeof data == 'string'
			data = [data]

		mod =
			$set:
				visible_to: data

		n = Posts.update(item_id, mod)
		return n

