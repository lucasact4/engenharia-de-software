class AddIpAddressToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_events, :ip_address, :string, limit: 45
  end
end
