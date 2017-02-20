FactoryGirl.define do
  factory :todo do
    project factory: :empty_project
    author
    user
    target factory: :issue
    action { Todo::ASSIGNED }

    trait :assigned do
      action { Todo::ASSIGNED }
    end

    trait :mentioned do
      action { Todo::MENTIONED }
    end

    trait :directly_addressed do
      action { Todo::DIRECTLY_ADDRESSED }
    end

    trait :on_commit do
      commit_id RepoHelpers.sample_commit.id
      target_type "Commit"
    end

    trait :build_failed do
      action { Todo::BUILD_FAILED }
      target factory: :merge_request
    end

    trait :marked do
      action { Todo::MARKED }
    end

    trait :approval_required do
      action { Todo::APPROVAL_REQUIRED }
    end

    trait :unmergeable do
      action { Todo::UNMERGEABLE }
    end

    trait :done do
      state :done
    end
  end
end
