# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::Summary::Group::StageSummary do
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group) }
  let(:project_2) { create(:project, :repository, namespace: group) }
  let(:from) { 1.day.ago }
  let(:user) { create(:user, :admin) }

  subject { described_class.new(group, options: { from: Time.now, current_user: user }).data }

  describe "#new_issues" do
    context 'with from date' do
      before do
        Timecop.freeze(5.days.ago) { create(:issue, project: project) }
        Timecop.freeze(5.days.ago) { create(:issue, project: project_2) }
        Timecop.freeze(5.days.from_now) { create(:issue, project: project) }
        Timecop.freeze(5.days.from_now) { create(:issue, project: project_2) }
      end

      it "finds the number of issues created after it" do
        expect(subject.first[:value]).to eq('2')
      end

      it 'returns the localized title' do
        Gitlab::I18n.with_locale(:ru) do
          expect(subject.first[:title]).to eq(n_('New Issue', 'New Issues', 2))
        end
      end

      context 'with subgroups' do
        before do
          Timecop.freeze(5.days.from_now) { create(:issue, project: create(:project, namespace: create(:group, parent: group))) }
        end

        it "finds issues from them" do
          expect(subject.first[:value]).to eq('3')
        end
      end

      context 'with projects specified in options' do
        before do
          Timecop.freeze(5.days.from_now) { create(:issue, project: create(:project, namespace: group)) }
        end

        subject { described_class.new(group, options: { from: Time.now, current_user: user, projects: [project.id, project_2.id] }).data }

        it 'finds issues from those projects' do
          expect(subject.first[:value]).to eq('2')
        end
      end

      context 'with `assignee_username` filter' do
        let(:assignee) { create(:user) }

        before do
          issue = project.issues.last
          issue.assignees << assignee
        end

        subject { described_class.new(group, options: { from: Time.now, current_user: user, assignee_username: [assignee.username] }).data }

        it 'finds issues from those projects' do
          expect(subject.first[:value]).to eq('1')
        end
      end

      context 'with `author_username` filter' do
        let(:author) { create(:user) }

        before do
          project.issues.last.update!(author: author)
        end

        subject { described_class.new(group, options: { from: Time.now, current_user: user, author_username: [author.username] }).data }

        it 'finds issues from those projects' do
          expect(subject.first[:value]).to eq('1')
        end
      end

      context 'with `label_name` filter' do
        let(:label1) { create(:group_label, group: group) }
        let(:label2) { create(:group_label, group: group) }

        before do
          issue = project.issues.last

          Issues::UpdateService.new(
            issue.project,
            user,
            label_ids: [label1.id, label2.id]
          ).execute(issue)
        end

        subject { described_class.new(group, options: { from: Time.now, current_user: user, label_name: [label1.name, label2.name] }).data }

        it 'finds issue with two labels' do
          expect(subject.first[:value]).to eq('1')
        end
      end

      context 'when `from` and `to` parameters are provided' do
        subject { described_class.new(group, options: { from: 10.days.ago, to: Time.now, current_user: user }).data }

        it 'finds issues from 5 days ago' do
          expect(subject.first[:value]).to eq('2')
        end
      end
    end

    context 'with other projects' do
      before do
        Timecop.freeze(5.days.from_now) { create(:issue, project: create(:project, namespace: create(:group))) }
        Timecop.freeze(5.days.from_now) { create(:issue, project: project) }
        Timecop.freeze(5.days.from_now) { create(:issue, project: project_2) }
      end

      it "doesn't find issues from them" do
        expect(subject.first[:value]).to eq('2')
      end
    end
  end

  describe "#deploys" do
    context 'with from date' do
      before do
        Timecop.freeze(5.days.ago) { create(:deployment, :success, project: project) }
        Timecop.freeze(5.days.from_now) { create(:deployment, :success, project: project) }
        Timecop.freeze(5.days.ago) { create(:deployment, :success, project: project_2) }
        Timecop.freeze(5.days.from_now) { create(:deployment, :success, project: project_2) }
      end

      it "finds the number of deploys made created after it" do
        expect(subject.second[:value]).to eq('2')
      end

      it 'returns the localized title' do
        Gitlab::I18n.with_locale(:ru) do
          expect(subject.second[:title]).to eq(n_('Deploy', 'Deploys', 2))
        end
      end

      context 'with subgroups' do
        before do
          Timecop.freeze(5.days.from_now) do
            create(:deployment, :success, project: create(:project, :repository, namespace: create(:group, parent: group)))
          end
        end

        it "finds deploys from them" do
          expect(subject.second[:value]).to eq('3')
        end
      end

      context 'with projects specified in options' do
        before do
          Timecop.freeze(5.days.from_now) do
            create(:deployment, :success, project: create(:project, :repository, namespace: group, name: 'not_applicable'))
          end
        end

        subject { described_class.new(group, options: { from: Time.now, current_user: user, projects: [project.id, project_2.id] }).data }

        it 'shows deploys from those projects' do
          expect(subject.second[:value]).to eq('2')
        end
      end

      context 'when `from` and `to` parameters are provided' do
        subject { described_class.new(group, options: { from: 10.days.ago, to: Time.now, current_user: user }).data }

        it 'finds deployments from 5 days ago' do
          expect(subject.second[:value]).to eq('2')
        end
      end
    end

    context 'with other projects' do
      before do
        Timecop.freeze(5.days.from_now) do
          create(:deployment, :success, project: create(:project, :repository, namespace: create(:group)))
        end
      end

      it "doesn't find deploys from them" do
        expect(subject.second[:value]).to eq('-')
      end
    end
  end

  describe '#deployment_frequency' do
    let(:from) { 6.days.ago }
    let(:to) { nil }

    subject do
      described_class.new(group, options: {
        from: from,
        to: to,
        current_user: user
      }).data.third
    end

    it 'includes the unit: `per day`' do
      expect(subject[:unit]).to eq(_('per day'))
    end

    before do
      Timecop.freeze(5.days.ago) do
        create(:deployment, :success, project: project)
      end
    end

    context 'when `to` is nil' do
      it 'includes range until now' do
        # 1 deployment over 7 days
        expect(subject[:value]).to eq('0.1')
      end
    end

    context 'when `to` is given' do
      let(:from) { 10.days.ago }
      let(:to) { 10.days.from_now }

      before do
        Timecop.freeze(5.days.from_now) do
          create(:deployment, :success, project: project)
        end
      end

      it 'returns deployment frequency within `from` and `to` range' do
        # 2 deployments over 20 days
        expect(subject[:value]).to eq('0.1')
      end
    end
  end
end
