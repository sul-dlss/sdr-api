class CreateBackgroundJobResults < ActiveRecord::Migration[6.0]
  def change
    execute <<-SQL
      CREATE TYPE background_job_result_status AS ENUM (
        'pending', 'processing', 'complete'
      );
    SQL
    create_table :background_job_results do |t|
      t.json :output, default: {}
      t.column :status, :background_job_result_status, default: 'pending'

      t.timestamps
    end
  end
end
