class CreateCacheContents < ActiveRecord::Migration[5.2]
  def change
    create_table :cache_contents do |t|
      t.string :cache_hash
      t.datetime :downloaded_timestamp

      t.timestamps
    end
  end
end
