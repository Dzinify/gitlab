# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Analytics::Reports do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:report_id) { 'recent_merge_requests_by_group' }

  shared_examples 'error response examples' do
    context 'when `report_pages` feature flag is off' do
      before do
        stub_feature_flags(report_pages: false)
      end

      it 'returns 404, not found' do
        api_call

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when `report_pages` license is missing' do
      before do
        stub_feature_flags(report_pages: true)
        stub_licensed_features(group_activity_analytics: false)
      end

      it 'returns 404, not found' do
        api_call

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /analytics/reports/:id/chart' do
    subject(:api_call) do
      get api("/analytics/reports/#{report_id}/chart?group_id=#{group.id}", user)
    end

    before do
      stub_licensed_features(group_activity_analytics: true)
    end

    it 'is successful' do
      api_call

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.parsed_body['id']).to eq(report_id)
      expect(response.parsed_body).to match_schema('analytics/reports/chart', dir: 'ee')
    end

    context 'when unknown report_id is given' do
      let(:report_id) { 'unknown_report_id' }

      it 'renders 404, not found' do
        api_call

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response.parsed_body['message']).to eq('404 Report(unknown_report_id) Not Found')
      end
    end

    include_examples 'error response examples'
  end

  describe 'GET /analytics/series/:report_id/:series_id' do
    let_it_be(:series_id) { 'open_merge_requests' }

    subject(:api_call) do
      get api("/analytics/series/#{report_id}/#{series_id}?group_id=#{group.id}", user)
    end

    it 'is successful' do
      api_call

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.parsed_body['datasets'].size).to eq(1)
    end

    context 'when unknown series_id is given' do
      let(:series_id) { 'unknown_series_id' }

      it 'renders 404, not found' do
        api_call

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response.parsed_body['message']).to eq('404 Series(unknown_series_id) Not Found')
      end
    end

    include_examples 'error response examples'
  end
end
