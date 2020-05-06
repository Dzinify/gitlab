# frozen_string_literal: true

require 'spec_helper'

describe 'Epics (JavaScript fixtures)' do
  include ApplicationHelper
  include JavaScriptFixturesHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'frontend-fixtures-group' )}
  let_it_be(:label) { create(:group_label, group: group, title: 'bug') }
  let_it_be(:public_project) { create(:project, :public, group: group) }
  let_it_be(:milestone1) { create(:milestone, group: group, title: 'Decade A', start_date: '2010-01-01', due_date: '2019-12-31')}
  let_it_be(:milestone2) { create(:milestone, group: group, title: 'Decade B', start_date: '2020-01-01', due_date: '2029-12-31')}
  let_it_be(:issue1) { create(:issue, project: public_project, milestone: milestone1)}
  let_it_be(:issue2) { create(:issue, project: public_project, milestone: milestone2)}

  let_it_be(:markdown) do
    <<-MARKDOWN.strip_heredoc
    This is an Epic description.

    This is a task list:

    - [ ] Incomplete entry 1
    MARKDOWN
  end

  let_it_be(:epic) { create(:epic, group: group, title: 'This is a sample epic', description: markdown, start_date_fixed: '2018-06-01', due_date_fixed: '2018-08-01') }

  let_it_be(:epic_issues) do
    [
      create(:epic_issue, epic: epic, issue: issue1, relative_position: 1),
      create(:epic_issue, epic: epic, issue: issue2, relative_position: 2)
    ]
  end

  before_all do
    clean_frontend_fixtures('epic/')
  end

  describe EpicPresenter, '(JavaScript fixtures)', type: :presenter do
    let(:response) { @json_data.to_json }

    it 'epic/mock_meta.json' do
      presenter = EpicPresenter.new(epic, current_user: user)

      @json_data = presenter.show_data(base_data: {}, author_icon: 'icon_path')
    end
  end

  describe IssuablesHelper, '(JavaScript fixtures)', type: :helper do
    let(:response) { @json_data.to_json }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).and_return(true)
    end

    it 'epic/mock_data.json' do
      @group = epic.group

      @json_data = helper.issuable_initial_data(epic)
    end
  end
end
