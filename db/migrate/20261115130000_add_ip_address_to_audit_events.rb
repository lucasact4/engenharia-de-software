class AddIpAddressToAuditEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :audit_events, :ip_address, :string, limit: 45
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "O IP administrativo integra o histórico auditável."
  end
end
