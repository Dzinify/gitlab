# frozen_string_literal: true

module Ci
  module PipelineProcessing
    class AtomicProcessingService
      class StatusCollection
        include Gitlab::Utils::StrongMemoize

        attr_reader :pipeline

        # We use these columns to perform an efficient
        # calculation of a status
        STATUSES_COLUMNS = [
          :id, :name, :status, :allow_failure,
          :stage_idx, :processed, :lock_version
        ].freeze

        def initialize(pipeline)
          @pipeline = pipeline
          @stage_statuses = {}
          @prior_stage_statuses = {}
        end

        # This method updates internal status for given ID
        def set_processable_status(id, status, lock_version)
          processable = all_statuses_by_id[id]
          return unless processable

          processable[:status] = status
          processable[:lock_version] = lock_version
        end

        # This methods gets composite status of all processables
        def status_of_all
          status_for_array(all_statuses, dag: false)
        end

        # This methods gets composite status for processables with given names
        def status_for_names(names, dag:)
          name_statuses = all_statuses_by_name.slice(*names).values
          dependency_tree_statuses = status_for_dependency_tree(name_statuses)

          status_for_array(name_statuses + dependency_tree_statuses, dag: dag)
        end

        # This methods gets composite status for processables before given stage
        def status_for_prior_stage_position(position)
          strong_memoize("status_for_prior_stage_position_#{position}") do
            stage_statuses = all_statuses_grouped_by_stage_position
              .select { |stage_position, _| stage_position < position }

            status_for_array(stage_statuses.values.flatten, dag: false)
          end
        end

        # This methods gets a list of processables for a given stage
        def created_processable_ids_for_stage_position(current_position)
          all_statuses_grouped_by_stage_position[current_position]
            .to_a
            .select { |processable| processable[:status] == 'created' }
            .map { |processable| processable[:id] }
        end

        # This methods gets composite status for processables at a given stage
        def status_for_stage_position(current_position)
          strong_memoize("status_for_stage_position_#{current_position}") do
            stage_statuses = all_statuses_grouped_by_stage_position[current_position].to_a

            status_for_array(stage_statuses.flatten, dag: false)
          end
        end

        # This method returns a list of all processable, that are to be processed
        def processing_processables
          all_statuses.lazy.reject { |status| status[:processed] }
        end

        private

        def status_for_array(statuses, dag:)
          if !Gitlab::Ci::Features.dag_behaves_same_as_stage? &&
              dag && statuses.any? { |status| HasStatus::COMPLETED_STATUSES.exclude?(status[:status]) }
            # TODO: This is hack to support
            # the same exact behaviour for Atomic and Legacy processing
            # that DAG is blocked from executing if dependent is not "complete"
            return 'pending'
          end

          result = Gitlab::Ci::Status::Composite
            .new(statuses)
            .status
          result || 'success'
        end

        def all_statuses_grouped_by_stage_position
          strong_memoize(:all_statuses_by_order) do
            all_statuses.group_by { |status| status[:stage_idx].to_i }
          end
        end

        def all_statuses_by_id
          strong_memoize(:all_statuses_by_id) do
            all_statuses.map do |row|
              [row[:id], row]
            end.to_h
          end
        end

        def all_statuses_by_name
          strong_memoize(:statuses_by_name) do
            all_statuses.map do |row|
              [row[:name], row]
            end.to_h
          end
        end

        # rubocop: disable CodeReuse/ActiveRecord
        def all_statuses
          # We fetch all relevant data in one go.
          #
          # This is more efficient than relying
          # on PostgreSQL to calculate composite status
          # for us
          #
          # Since we need to reprocess everything
          # we can fetch all of them and do processing
          # ourselves.
          strong_memoize(:all_statuses) do
            raw_statuses = pipeline
              .statuses
              .latest
              .ordered_by_stage
              .pluck(*STATUSES_COLUMNS)

            raw_statuses.map do |row|
              STATUSES_COLUMNS.zip(row).to_h
            end
          end
        end
        # rubocop: enable CodeReuse/ActiveRecord

        def status_for_dependency_tree(name_statuses)
          return [] unless Gitlab::Ci::Features.dependency_tree_for_dag?

          name_statuses.map do |status|
            # If the status is success of can be ignore, we don't need to fetch its dependencies.
            # Besides, it leads to wrong calculations when using `when:on_failure`.
            next if status[:status] == 'success' || ignored_status?(status)

            {
              status: status_for_prior_stage_position(status[:stage_idx]),
              allow_failure: false
            }
          end.compact.uniq
        end

        def ignored_status?(status)
          status[:allow_failure] && HasStatus::EXCLUDE_IGNORED_STATUSES.include?(status[:status])
        end
      end
    end
  end
end
