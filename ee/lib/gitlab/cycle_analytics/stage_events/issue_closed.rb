# frozen_string_literal: true

module Gitlab
  module CycleAnalytics
    module StageEvents
      class IssueClosed < SimpleStageEvent
        def self.identifier
          :issue_closed
        end

        def object_type
          Issue
        end

        def timestamp_projection
          issue_table[:closed_at]
        end
      end
    end
  end
end
