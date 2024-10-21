# frozen_string_literal: true

# /status for 'upness', e.g. for load balancer
# /status/all to show all dependencies
# /status/<name-of-check> for a specific check (e.g. for nagios warning)
OkComputer.mount_at = 'status'
OkComputer.check_in_parallel = true

# spot check tables for data loss
class TablesHaveDataCheck < OkComputer::Check
  def check
    msg = [
      User,
      BackgroundJobResult
    ].map { |klass| table_check(klass) }.join(' ')
    mark_message msg
  end

  private

  # @return [String] message
  def table_check(klass)
    # has at least 1 record
    return "#{klass.name} has data." if klass.any?

    mark_failure
    "#{klass.name} has no data."
  rescue => e # rubocop:disable Style/RescueStandardError
    mark_failure
    "#{e.class.name} received: #{e.message}."
  end
end

# make sure we can hit the workflow service
class WorkflowServerCheck < OkComputer::Check
  def check
    num_templates = Workflow.workflow_client.workflow_templates.size
    mark_message "#{Settings.workflow.url} has #{num_templates} templates."

    mark_failure if num_templates.zero?
  rescue StandardError => e
    mark_message e.message
    mark_failure
  end
end

# confirm that the expected number of sidekiq worker processes and threads are running
class SidekiqWorkerCountCheck < OkComputer::Check
  class ExpectedEnvVarMissing < StandardError; end

  def check # rubocop:disable Metrics/MethodLength
    actual_local_sidekiq_processes = fetch_local_sidekiq_processes
    actual_local_sidekiq_process_count = actual_local_sidekiq_processes.size
    actual_local_total_concurrency = actual_local_sidekiq_processes.sum { |process| process['concurrency'] }

    error_list = calculate_error_list(actual_local_sidekiq_process_count:,
                                      actual_local_total_concurrency:)

    if error_list.empty?
      mark_message "Sidekiq worker counts as expected on this VM: #{actual_local_sidekiq_process_count} worker " \
                   "processes, #{actual_local_total_concurrency} concurrent worker threads total."
    else
      mark_message error_list.join('  ')
      mark_failure
    end
  rescue ExpectedEnvVarMissing => e
    mark_message e.message
    mark_failure
  end

  private

  # @return [Array<Sidekiq::Process>] one Sidekiq::Process object for each worker management
  #   process currently running on _this_ VM
  def fetch_local_sidekiq_processes
    fetch_global_sidekiq_process_list.select do |p|
      p['hostname'] == Socket.gethostname
    end
  end

  # @return [Array<Sidekiq::Process>] one Sidekiq::Process object for each worker management
  #   process currently running on _all_ worker VMs
  def fetch_global_sidekiq_process_list
    # Sidekiq::ProcessSet#each doesn't return an Enumerator, it just loops and calls the block it's passed
    Sidekiq::ProcessSet.new.map { |process| process }
  end

  # the number of concurrent Sidekiq worker threads per process is set in config/sidekiq.yml
  def expected_sidekiq_proc_concurrency(proc_num: nil)
    config_filename = proc_num.present? ? "../../shared/config/sidekiq#{proc_num}.yml" : 'config/sidekiq.yml'
    sidekiq_config = YAML.safe_load(Rails.root.join(config_filename).read, permitted_classes: [Symbol])
    sidekiq_config[:concurrency]
  end

  # puppet runs a number of sidekiq processes using systemd, exposing the expected process count via env var
  def expected_sidekiq_process_count
    @expected_sidekiq_process_count ||= Integer(ENV.fetch('EXPECTED_SIDEKIQ_PROC_COUNT'))
  rescue StandardError => e
    err_description = 'Error retrieving EXPECTED_SIDEKIQ_PROC_COUNT and parsing to int. ' \
                      "ENV['EXPECTED_SIDEKIQ_PROC_COUNT']=#{ENV.fetch('EXPECTED_SIDEKIQ_PROC_COUNT', nil)}"
    Rails.logger.error("#{err_description} -- #{e.message} -- #{e.backtrace}")
    raise ExpectedEnvVarMissing, err_description
  end

  def expected_local_total_concurrency
    # Existence of config/sidekiq.yml indicates a single config for all sidekiq processes. otherwise, each of
    # the sidekiq processes, 1 through EXPECTED_SIDEKIQ_PROC_COUNT, will have its own config file.
    # The number of sidekiq[N].yml files may not match the number of sidekiq processes if custom_execstart=false
    # in puppet config.
    @expected_local_total_concurrency ||=
      if File.exist?('config/sidekiq.yml')
        expected_sidekiq_process_count * expected_sidekiq_proc_concurrency
      else
        (1..expected_sidekiq_process_count).sum { |n| expected_sidekiq_proc_concurrency(proc_num: n) }
      end
  end

  def calculate_error_list(actual_local_sidekiq_process_count:, actual_local_total_concurrency:) # rubocop:disable Metrics/MethodLength
    error_list = []

    if actual_local_sidekiq_process_count > expected_sidekiq_process_count
      error_list << <<~ERR_TXT
        Actual Sidekiq worker process count (#{actual_local_sidekiq_process_count}) on this VM is greater than \
        expected (#{expected_sidekiq_process_count}). Check for stale Sidekiq processes (e.g. from old deployments). \
        It's also possible that some worker threads are finishing WIP that started before a Sidekiq restart, e.g. as \
        happens when long running job spans app deployment. Use your judgement when deciding whether to kill an old process.
      ERR_TXT
    end
    if actual_local_sidekiq_process_count < expected_sidekiq_process_count
      error_list << "Actual Sidekiq worker management process count (#{actual_local_sidekiq_process_count}) on " \
                    "this VM is less than expected (#{expected_sidekiq_process_count})."
    end
    if actual_local_total_concurrency != expected_local_total_concurrency
      error_list << "Actual worker thread count on this VM is #{actual_local_total_concurrency}, but " \
                    "expected local total Sidekiq concurrency is #{expected_local_total_concurrency}."
    end

    error_list
  end
end

# REQUIRED checks, required to pass for /status/all
#  individual checks also avail at /status/<name-of-check>
OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new
OkComputer::Registry.register 'background_jobs', OkComputer::SidekiqLatencyCheck.new('default', 25)
OkComputer::Registry.register 'feature-tables-have-data', TablesHaveDataCheck.new
OkComputer::Registry.register 'sidekiq_worker_count', SidekiqWorkerCountCheck.new
OkComputer::Registry.register 'workflow_server', WorkflowServerCheck.new
