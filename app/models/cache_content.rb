class CacheContent < ApplicationRecord

  has_one_attached :content

  def self.new_from_request_and_response(request, response, content, content_version = nil)
    # check
    raise "Invalid. request.url is blank." if request["url"].blank?
    raise "Invalid. request.method is blank." if request["method"].blank?
    raise "Invalid. request.method is not GET or POST. (method=#{request["method"]})" if request["method"] != "GET" && request["method"] != "POST"
    raise "Invalid. request.headers is not Hash." if request["parameters"].present? && (not request["parameters"].instance_of?(Hash))
    raise "Invalid. response.headers is blank." if response["headers"].blank?
    raise "Invalid. content is nil." if content.nil?
    raise "Invalid. content_version is not integer. (content_version=#{content_version})" if content_version.present? && (not content_version.integer?)

    # build upload content
    cache_hash = OpenSSL::Digest::SHA256.hexdigest(request.to_json)
    if content_version.nil?
      content_version = Time.zone.now.utc.to_i
    end

    content_meta = {
      "request" => request,
      "response" => response,
      "cached_timestamp" => content_version,
    }

    # content 7zip compress
    content_data_7z = StringIO.new("")
    SevenZipRuby::Writer.open(content_data_7z) do |szr|
      szr.level = 9
      szr.add_data(content_meta.to_json, cache_hash + ".meta")
      szr.add_data(content, cache_hash + ".bin")
    end

    content_data_7z.rewind
    raise "Compress error" if not SevenZipRuby::Reader.verify(content_data_7z)

    content_data_7z.rewind

    # ContentCache new, attach, save
    cache_content = CacheContent.new(cache_hash: cache_hash, content_version: content_version)
    cache_content.content.attach(io: content_data_7z, filename: cache_hash + ".7z")

    # return
    cache_content
  end

  def self.find_by_request(request)
    # check
    raise "Invalid. url is blank." if request["url"].blank?
    raise "Invalid. method is blank." if request["method"].blank?
    raise "Invalid. method is not GET or POST. (method=#{request["method"]})" if request["method"] != "GET" && request["method"] != "POST"
    raise "Invalid. request.headers is not Hash." if request["parameters"].present? && (not request["parameters"].instance_of?(Hash))

    # find CacheContent
    cache_hash = OpenSSL::Digest::SHA256.hexdigest(request.to_json)

    cache = CacheContent.where(cache_hash: cache_hash).order(content_version: :desc).first
  end

  def to_cache
    # download content_data, and decompress
    content_data_7z = self.content.download

    content_meta = nil
    content = nil
    SevenZipRuby::Reader.open(StringIO.new(content_data_7z)) do |szr|
      szr.entries.each do |entry|
        pp entry.path
        if entry.path.end_with?(".meta")
          content_meta = JSON.parse(szr.extract_data(entry))
        elsif entry.path.end_with?(".bin")
          content = szr.extract_data(entry)
        end
      end
    end

    raise "Invalid. meta or bin not found." if content_meta.nil? || content.nil?

    # build cache
    cache = {
      "request" => content_meta["request"],
      "response" => content_meta["response"],
      "cached_timestamp" => content_meta["cached_timestamp"],
      "content" => content
    }

    # return
    cache
  end

end
