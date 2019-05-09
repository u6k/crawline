class CrawlineCaches < ActiveRecord::Migration[5.2]
  def change
    create_table :crawline_caches do |t|
      t.string :url
      t.string :request_method
      t.datetime :downloaded_timestamp
      t.string :storage_path
    end

    create_table :crawline_headers do |t|
      t.belongs_to :crawline_cache, index: true, foreign_key: true
      t.string :message_type
      t.string :header_name
      t.string :header_value
    end

    create_table :crawline_related_links do |t|
      t.belongs_to :crawline_cache, index: true, foreign_key: true
      t.string :url
    end
  end
end
