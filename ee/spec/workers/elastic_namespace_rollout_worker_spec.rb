# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticNamespaceRolloutWorker do
  before do
    stub_const('ROLLOUT', described_class::ROLLOUT)
    stub_const('ROLLBACK', described_class::ROLLBACK)
  end

  Plan::PAID_HOSTED_PLANS.each do |plan|
    plan_factory = "#{plan}_plan"
    let_it_be(plan_factory) { create(plan_factory) }
  end

  before_all do
    Plan::PAID_HOSTED_PLANS.each do |plan|
      create_list(:gitlab_subscription, 4, hosted_plan: public_send("#{plan}_plan"))
    end
  end

  def expect_percentage_to_result_in_records(percentage, record_count, mode)
    subject.perform('gold', percentage, mode)

    namespace_ids = GitlabSubscription
      .with_hosted_plan('gold')
      .order(id: :asc)
      .pluck(:namespace_id)

    expect(
      ElasticsearchIndexedNamespace.pluck(:namespace_id)
    ).to contain_exactly(*namespace_ids.first(record_count))
  end

  def get_namespace_ids(plan, count)
    GitlabSubscription
      .with_hosted_plan(plan)
      .order(id: :asc)
      .pluck(:namespace_id)
      .first(count)
  end

  it 'rolls out and back' do
    # Rollout
    expect_percentage_to_result_in_records(0, 0, ROLLOUT)
    expect_percentage_to_result_in_records(50, 2, ROLLOUT)
    expect_percentage_to_result_in_records(25, 2, ROLLOUT) # no op
    expect_percentage_to_result_in_records(100, 4, ROLLOUT)

    # Rollback
    expect_percentage_to_result_in_records(50, 2, ROLLBACK)
    expect_percentage_to_result_in_records(75, 2, ROLLBACK) # no op
    expect_percentage_to_result_in_records(0, 0, ROLLBACK)
  end

  it 'distinguishes different plans' do
    # Rollout
    subject.perform('gold', 50, ROLLOUT)
    subject.perform('silver', 25, ROLLOUT)

    expect(
      ElasticsearchIndexedNamespace.pluck(:namespace_id)
    ).to contain_exactly(
      *get_namespace_ids(:gold, 2),
      *get_namespace_ids(:silver, 1)
    )

    # Rollback
    subject.perform('gold', 25, ROLLBACK)
    subject.perform('silver', 0, ROLLBACK)

    expect(
      ElasticsearchIndexedNamespace.pluck(:namespace_id)
    ).to contain_exactly(
      *get_namespace_ids(:gold, 1)
    )
  end

  it 'logs' do
    logger = subject.send(:logger)

    expect(logger).to receive(:info).with(
      hash_including(
        message: "rollout_elasticsearch_indexed_namespaces",
        changes: 3,
        expected_count: 3,
        current_count: 0,
        plan: 'gold'
      )
    ).and_call_original

    subject.perform('gold', 75, ROLLOUT)

    expect(logger).to receive(:info).with(
      hash_including(
        message: "rollback_elasticsearch_indexed_namespaces",
        changes: 2,
        expected_count: 1,
        current_count: 3,
        plan: 'gold'
      )
    ).and_call_original

    subject.perform('gold', 25, ROLLBACK)
  end
end
