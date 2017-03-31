module Notes
  class BuildService < BaseService
    def execute
      in_reply_to_discussion_id = params.delete(:in_reply_to_discussion_id)
      new_discussion = params.delete(:new_discussion)

      if project && in_reply_to_discussion_id.present?
        discussion = project.notes.find_discussion(in_reply_to_discussion_id)

        unless discussion
          note = Note.new
          note.errors.add(:base, 'Discussion to reply to cannot be found')
          return note
        end

        params.merge!(discussion.reply_attributes)
      elsif new_discussion
        # TODO: Remove when we use a selectbox instead of a submit button
        params[:type] = DiscussionNote.name
      end

      note = Note.new(params)
      note.project = project
      note.author = current_user

      note
    end
  end
end
