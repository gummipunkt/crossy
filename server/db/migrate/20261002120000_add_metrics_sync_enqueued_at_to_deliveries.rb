class AddMetricsSyncEnqueuedAtToDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :deliveries, :metrics_sync_enqueued_at, :datetime
  end
end
