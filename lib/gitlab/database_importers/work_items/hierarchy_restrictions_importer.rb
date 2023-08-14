# frozen_string_literal: true

module Gitlab
  module DatabaseImporters
    module WorkItems
      module HierarchyRestrictionsImporter
        def self.upsert_restrictions
          objective = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:objective])
          key_result = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:key_result])
          issue = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:issue])
          task = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:task])
          incident = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:incident])
          epic = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:epic])
          ticket = find_or_create_type(::WorkItems::Type::TYPE_NAMES[:ticket])

          restrictions = [
            { parent_type_id: objective.id, child_type_id: objective.id, maximum_depth: 9 },
            { parent_type_id: objective.id, child_type_id: key_result.id, maximum_depth: 1 },
            { parent_type_id: issue.id, child_type_id: task.id, maximum_depth: 1 },
            { parent_type_id: incident.id, child_type_id: task.id, maximum_depth: 1 },
            { parent_type_id: epic.id, child_type_id: epic.id, maximum_depth: 9 },
            { parent_type_id: epic.id, child_type_id: issue.id, maximum_depth: 1 },
            { parent_type_id: ticket.id, child_type_id: task.id, maximum_depth: 1 }
          ]

          ::WorkItems::HierarchyRestriction.upsert_all(
            restrictions,
            unique_by: :index_work_item_hierarchy_restrictions_on_parent_and_child
          )
        end

        def self.find_or_create_type(name)
          type = ::WorkItems::Type.find_by_name_and_namespace_id(name, nil)
          return type if type

          Gitlab::DatabaseImporters::WorkItems::BaseTypeImporter.upsert_types
          ::WorkItems::Type.find_by_name_and_namespace_id(name, nil)
        end
      end
    end
  end
end
