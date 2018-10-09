class CacheContent < ApplicationRecord

  has_one_attached :content

  def self.new_from_request_and_response(request, response, content, content_version = nil)
    # check
    raise "Invalid. request.url is empty." if request[:url].blank?
    raise "Invalid. request.method is empty." if request[:method].blank?
    raise "Invalid. request.method is not GET or POST. (method=#{request[:method]})" if request[:method] != "GET" && downloaded_content[:method] != "POST"
    raise "Invalid. request.headers is not Hash." if request[:parameters].present? && (not request[:parameters].instance_of?(Hash))
    raise "Invalid. response.headers is empty." if response[:headers].blank?
    raise "Invalid. content is empty." if content.blank?
    raise "Invalid. content_version is not integer. (content_version=#{content_version})" if content_version.present? && (not content_version.integer?)

    # build upload content
    cache_hash = OpenSSL::Digest::SHA256.hexdigest(request.to_json)
    if content_version.nil?
      content_version = Time.zone.now.utc.to_i
    end

    content_data = {
      request: request,
      response: response,
      cached_timestamp: content_version,
      content: "Base64:" + Base64.strict_encode64(content),
      content_hash: "SHA256:" + OpenSSL::Digest::SHA256.hexdigest(content)
    }

    # content 7zip compress
    content_data_7z = StringIO.new("")
    SevenZipRuby::Writer.open(content_data_7z) do |szr|
      szr.level = 9
      szr.add_data(content_data.to_json, cache_hash + ".7z")
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
    if request[:url].empty?
      raise "Invalid. url is empty."
    end
    if request[:method].empty?
      raise "Invalid. method is empty."
    end
    if request[:method] != "GET" && request[:method] != "POST"
      raise "Invalid. method is not GET or POST. (method=#{request[:method]})"
    end

    # find CacheContent
    cache_hash = OpenSSL::Digest::SHA256.hexdigest(content.to_json)

    cache = CacheContent.where(cache_hash: cache_hash).order("downloaded_timestamp desc").first
  end

  def to_cache
    # download content_data, and decompress
    content_data = self.content.download

    SevenZipRuby::Reader.open(content_data) do |szr|
      content = szr.extract_data(szr.entries[0])
    end

    # build cache
    cache = {
      url: content[:url],
      method: content[:method]
    }
    if not content[:request_parameters].empty?
      cache[:request_parameters] = content[:request_parameters]
    end
    cache[:response_headers] = content[:response_headers]
    cache[:downloaded_timestamp] = content[:downloaded_timestamp]

    raise "Invalid. content not start with 'Base64:'." if not content[:content].start_with?("Base64:")

    cache[:content] = Base64.strict_decode64(content[:content][6, -1])

    raise "Invalid. content hash not match." if content[:content_hash] != OpenSSL::Digest::SHA256.hexdigest(cache[:content])

    # return
    cache
  end

end
