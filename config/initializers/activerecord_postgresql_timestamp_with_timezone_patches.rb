# frozen_string_literal: true

# Monkey patch to fix errors like `undefined method 'getutc' for Date' seen
# during Rails 7 upgrade:
#
# See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/90907#note_1253684870 and
# https://github.com/rails/rails/issues/46341#issuecomment-1406391573

if Rails.gem_version >= Gem::Version.new('7.0.5')
  raise "Remove `#{__FILE__}`. This is backport of https://github.com/rails/rails/pull/46365"
end

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class TimestampWithTimeZone < DateTime # :nodoc:
          def type
            real_type_unless_aliased(:timestamptz)
          end

          def cast_value(value)
            return if value.blank?

            time = super
            return time unless time.acts_like?(:time)

            # While in UTC mode, the PG gem may not return times back in "UTC" even if they were provided to
            # Postgres in UTC. We prefer times always in UTC, so here we convert back.
            if is_utc?
              time.getutc
            else
              time.getlocal
            end
          end
        end
      end
    end
  end
end
