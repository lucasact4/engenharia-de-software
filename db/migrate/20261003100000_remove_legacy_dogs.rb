# Remove somente o exemplo solicitado. O rollback recria a tabela, sem recuperar seus dados.
class RemoveLegacyDogs < ActiveRecord::Migration[8.1]
  def change
    drop_table :dogs do |t|
      t.string :name
      t.integer :age
      t.datetime :deleted_at
      t.timestamps
      t.index :deleted_at
    end
  end
end
