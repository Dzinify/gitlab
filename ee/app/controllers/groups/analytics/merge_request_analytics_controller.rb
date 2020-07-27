# frozen_string_literal: true

class Groups::Analytics::MergeRequestAnalyticsController < Groups::Analytics::ApplicationController
  check_feature_flag Gitlab::Analytics::GROUP_MERGE_REQUEST_ANALYTICS_FEATURE_FLAG

  layout 'group'

  before_action :load_group
  before_action -> {
    check_feature_availability!(:group_merge_request_analytics)
  }
  before_action -> {
    authorize_view_by_action!(:read_group_merge_request_analytics)
  }

  def show
  end
end
