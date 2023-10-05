# frozen_string_literal: true

module Gitlab
  module Geo
    module LogCursor
      module Events
        class ResetChecksumEvent
          include BaseEvent

          def process
            # no-op
          end
        end
      end
    end
  end
end
