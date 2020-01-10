# frozen_string_literal: true

require 'spec_helper'

describe Projects::PerformanceMonitoring::DashboardsController do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let!(:project) { create(:project, :repository, name: 'dashboard-project', namespace: namespace) }
  let(:repository) { project.repository }
  let(:branch) { double(name: branch_name) }
  let(:commit_message) { 'test' }
  let(:branch_name) { "#{Time.current.to_i}_dashboard_new_branch" }
  let(:dashboard) { 'config/prometheus/common_metrics.yml' }
  let(:file_name) { 'custom_dashboard.yml' }
  let(:params) do
    {
      namespace_id: namespace,
      project_id: project,
      dashboard: dashboard,
      file_name: file_name,
      commit_message: commit_message,
      branch: branch_name,
      format: :json
    }
  end

  describe 'POST #create' do
    context 'authenticated user' do
      before do
        sign_in(user)
      end

      context 'project with repository feature' do
        context 'with rights to push to the repository' do
          before do
            project.add_maintainer(user)
          end

          context 'valid parameters' do
            it 'delegates cloning to ::Metrics::Dashboard::CloneDashboardService' do
              allow(controller).to receive(:repository).and_return(repository)
              allow(repository).to receive(:find_branch).and_return(branch)
              dashboard_attrs = {
                dashboard: dashboard,
                file_name: file_name,
                commit_message: commit_message,
                branch: branch_name
              }

              service_instance = instance_double(::Metrics::Dashboard::CloneDashboardService)
              expect(::Metrics::Dashboard::CloneDashboardService).to receive(:new).with(project, user, dashboard_attrs).and_return(service_instance)
              expect(service_instance).to receive(:execute).and_return(status: :success, http_status: :created)

              post :create, params: params
            end

            context 'request format json' do
              it 'returns services response' do
                allow(::Metrics::Dashboard::CloneDashboardService).to receive(:new).and_return(double(execute: { status: :success, dashboard: {}, http_status: :created }))

                post :create, params: params

                expect(response).to have_gitlab_http_status :created
                expect(json_response).to eq('status' => 'success', 'dashboard' => {})
              end

              context 'Metrics::Dashboard::CloneDashboardService failure' do
                it 'returns json with failure message', :aggregate_failures do
                  allow(::Metrics::Dashboard::CloneDashboardService).to receive(:new).and_return(double(execute: { status: :error, message: 'something went wrong', http_status: :bad_request }))

                  post :create, params: params

                  expect(response).to have_gitlab_http_status :bad_request
                  expect(json_response).to eq('error' => 'something went wrong')
                end
              end

              %w(commit_message file_name dashboard).each do |param|
                context "param #{param} is missing" do
                  let(param.to_s) { nil }

                  it 'raises ActionController::ParameterMissing', :aggregate_failures do
                    post :create, params: params

                    expect(response).to have_gitlab_http_status :bad_request
                    expect(json_response).to eq('error' => "Request parameter #{param} is missing.")
                  end
                end
              end

              context "param branch_name is missing" do
                let(:branch_name) { nil }

                it 'raises ActionController::ParameterMissing', :aggregate_failures do
                  post :create, params: params

                  expect(response).to have_gitlab_http_status :bad_request
                  expect(json_response).to eq('error' => "Request parameter branch is missing.")
                end
              end
            end
          end
        end

        context 'without rights to push to repository' do
          before do
            project.add_guest(user)
          end

          it 'responds with :forbidden status code' do
            post :create, params: params

            expect(response).to have_gitlab_http_status :forbidden
          end
        end
      end

      context 'project without repository feature' do
        let!(:project) { create(:project, name: 'dashboard-project', namespace: namespace) }

        it 'responds with :not_found status code' do
          post :create, params: params

          expect(response).to have_gitlab_http_status :not_found
        end
      end
    end
  end
end
