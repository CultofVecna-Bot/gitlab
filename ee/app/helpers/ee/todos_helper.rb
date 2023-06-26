# frozen_string_literal: true

module EE
  module TodosHelper
    extend ::Gitlab::Utils::Override

    override :todo_types_options
    def todo_types_options
      super + [{ id: 'Epic', text: s_('Todos|Epic') }]
    end

    override :todo_author_display?
    def todo_author_display?(todo)
      super && !todo.merge_train_removed?
    end

    override :show_todo_state?
    def show_todo_state?(todo)
      super || (todo.target.is_a?(Epic) && todo.target.state == 'closed')
    end

    def todo_groups_requiring_saml_reauth(todos)
      groups = todos.filter_map { |todo| todo.group || todo.project.group }.uniq

      ::Gitlab::Auth::GroupSaml::SsoEnforcer.access_restricted_groups(groups, user: current_user)
    end

    def diff_llm_summary(todo)
      todo.target.latest_merge_request_diff&.merge_request_diff_llm_summary
    end
  end
end
