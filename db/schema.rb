# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_05_09_042450) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "crawline_caches", force: :cascade do |t|
    t.string "url"
    t.string "request_method"
    t.datetime "downloaded_timestamp"
    t.string "storage_path"
  end

  create_table "crawline_headers", force: :cascade do |t|
    t.bigint "crawline_cache_id"
    t.string "message_type"
    t.string "header_name"
    t.string "header_value"
    t.index ["crawline_cache_id"], name: "index_crawline_headers_on_crawline_cache_id"
  end

  create_table "crawline_related_links", force: :cascade do |t|
    t.bigint "crawline_cache_id"
    t.string "url"
    t.index ["crawline_cache_id"], name: "index_crawline_related_links_on_crawline_cache_id"
  end

  add_foreign_key "crawline_headers", "crawline_caches", column: "crawline_cache_id"
  add_foreign_key "crawline_related_links", "crawline_caches", column: "crawline_cache_id"
end
