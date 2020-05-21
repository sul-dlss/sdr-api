class AddTryCountToBackgroundJobResults < ActiveRecord::Migration[6.0]
  def change
    add_column :background_job_results, :try_count, :integer, default: 0
  end
end
