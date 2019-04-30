require "crawline/version"

require "aws-sdk-s3"
require "seven_zip_ruby"

module Crawline

  class Downloader
    def initialize(user_agent)
      @logger = CrawlineLogger.get_logger
      @logger.debug("Downloader#initialize: start")

      @user_agent = user_agent
    end

    def download_with_get(url)
      @logger.debug("Downloader#download_with_get: start: url=#{url}")

      uri = URI(url)

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = @user_agent
      req["Accept"] = "*/*"

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if url.start_with?("https://")

      @logger.debug("Downloader#download_with_get: request start")
      res = http.start do
        http.request(req)
      rescue Net::OpenTimeout
        raise DownloadError.new("timeout")
      end
      @logger.debug("Downloader#download_with_get: request end: response=#{res}")

      case res
      when Net::HTTPSuccess
        @logger.debug("Downloader#download_with_get: status is success")

        result = {
          "url" => url,
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => res.body,
          "downloaded_timestamp" => Time.now().utc()
        }

        req.each_key { |k| result["request_headers"][k] = req[k] }
        res.each_key { |k| result["response_headers"][k] = res[k] }

        result
      when Net::HTTPRedirection
        @logger.debug("Downloader#download_with_get: status is redirection")
        redirect_url = URI.join(url, res["location"]).to_s
        result = download_with_get(redirect_url)

        result["url"] = url

        result
      else
        @logger.debug("Downloader#download_with_get: status is else: code=#{res.code}, #{res.message}")
        raise DownloadError.new(res.code)
      end
    end
  end

  class ResourceRepository
    def initialize(access_key, secret_key, region, bucket, endpoint, force_path_style, object_name_suffix)
      @logger = CrawlineLogger.get_logger
      @logger.debug("ResourceRepository#initialize: start: access_key=#{access_key}, region=#{region}, bucket=#{bucket}, endpoint=#{endpoint}, force_path_style=#{force_path_style}, object_name_suffix=#{object_name_suffix}")

      Aws.config.update({
        region: region,
        credentials: Aws::Credentials.new(access_key, secret_key)
      })
      s3 = Aws::S3::Resource.new(endpoint: endpoint, force_path_style: force_path_style)
      @logger.debug("ResourceRepository#initialize: init s3 client")

      @bucket = s3.bucket(bucket)
      @logger.debug("ResourceRepository#initialize: get bucket")

      if not @bucket.exists?
        @logger.debug("ResourceRepository#initialize: bucket not exists")

        @bucket.create
        @logger.debug("ResourceRepository#initialize: bucket created")
      end

      @object_name_suffix = object_name_suffix
    end

    def put_s3_object(file_name, data)
      @logger.debug("ResourceRepository#put_s3_object: start: file_name=#{file_name}, data.nil?=#{data.nil?}")

      # Compress data
      store_data = compress_data(file_name, data)

      # Upload data to s3
      obj_original = @bucket.object((@object_name_suffix.nil? ? "" : @object_name_suffix + "/") + file_name + ".latest.7z")
      obj_original.put(body: store_data)
      @logger.debug("ResourceRepository#put_s3_object: put original object: data.size=#{store_data.size}")

      obj_backup = @bucket.object((@object_name_suffix.nil? ? "" : @object_name_suffix + "/") + file_name + "." + Time.now.to_i.to_s + ".7z")
      obj_backup.put(body: store_data)
      @logger.debug("ResourceRepository#put_s3_object: put backup object: data.size=#{store_data.size}")
    end

    def list_s3_objects
      @logger.debug("ResourceRepository#list_s3_objects: start")

      # Listing s3 object
      @bucket.objects.each do |obj|
        @logger.debug("ResourceRepository#list_s3_objects: object.key=#{obj.key}")

        if obj.key.end_with?(".latest.7z")
          # Download from s3
          stored_data = obj.get.body.read(obj.size)

          # Decompress data
          data = decompress_data(obj.key, stored_data)

          yield(data)
        end
      end
    end

    def get_s3_object(file_name)
      @logger.debug("ResourceRepository#get_s3_object: file_name=#{file_name}")

      # Download from s3
      object = @bucket.object((@object_name_suffix.nil? ? "" : @object_name_suffix + "/") + file_name + ".latest.7z")

      begin
        @logger.debug("ResourceRepository#get_s3_object: getting")
        stored_data = object.get.body.read(object.size)

        # Decompress data
        data = decompress_data(file_name, stored_data)
        @logger.debug("ResourceRepository#get_s3_object: getted: size=#{data.size}")
      rescue Aws::S3::Errors::NoSuchKey
        @logger.debug("ResourceRepository#get_s3_object: no such key")
        data = nil
      end

      data
    end

    def exists_s3_object?(file_name)
      @logger.debug("ResourceRepository#exists_s3_object?: file_name=#{file_name}")

      (not get_s3_object((@object_name_suffix.nil? ? "" : @object_name_suffix + "/") + file_name).nil?)
    end

    def remove_s3_objects
      @logger.debug("ResourceRepository#remove_s3_objects")

      @bucket.objects.batch_delete!
    end

    def remove_s3_object(file_name)
      @logger.debug("ResourceRepository#remove_s3_object: start: file_name=#{file_name}")

      @bucket.objects({prefix: file_name}).batch_delete!
    end

    def compress_data(file_name, data)
      compressed_data = nil

      StringIO.open("") do |io|
        SevenZipRuby::Writer.open(io) do |szr|
          szr.level = 9
          szr.add_data(data, file_name.split("/")[-1])
        end

        io.rewind
        raise "Compress error" if not SevenZipRuby::Reader.verify(io)

        io.rewind
        compressed_data = io.read
      end

      compressed_data
    end

    def decompress_data(file_name, compressed_data)
      data = nil

      StringIO.open(compressed_data) do |io|
        raise "Decompress error" if not SevenZipRuby::Reader.verify(io)

        io.rewind
        SevenZipRuby::Reader.open(io) do |szr|
          data = szr.extract_data(szr.entries[0])
        end
      end

      data
    end
  end

  class Engine
    def initialize(downloader, repo, parsers, interval = 1.0)
      @logger = CrawlineLogger.get_logger
      @logger.debug("Engine#initialize: start: downloader=#{downloader}, repo=#{repo}, parsers=#{parsers}")

      raise ArgumentError, "downloader is nil." if downloader.nil?
      raise ArgumentError, "repo is nil." if repo.nil?
      raise ArgumentError, "parsers is nil." if parsers.nil?

      raise TypeError, "downloader is not Crawline::Downloader." if not downloader.is_a?(Crawline::Downloader)
      raise TypeError, "repo is not Crawline::ResourceRepository." if not repo.is_a?(Crawline::ResourceRepository)
      parsers.each do |url_pattern, parser|
        raise TypeError, "parsers is not Hash<Regexp, Parser>." if not url_pattern.is_a?(Regexp)
        raise TypeError, "parsers is not Hash<Regexp, Parser>." if not (parser < Crawline::BaseParser)
      end

      @downloader = downloader
      @repo = repo
      @parsers = parsers
      @interval = interval
    end

    def crawl(url)
      @logger.debug("Engine#crawl: start: url=#{url}")

      url_list = [url]
      result = { "success_url_list" => [], "fail_url_list" => [], "context" => {} }

      until url_list.empty? do
        target_url = url_list.shift
        @logger.debug("Engine#crawl: target_url=#{target_url}")

        begin
          next_links = crawl_impl(target_url, result["context"])

          if not next_links.nil?
            next_links.each do |next_link|
              url_list << next_link if (not url_list.include?(next_link)) && (not result["success_url_list"].include?(next_link)) && (not result["fail_url_list"].include?(next_link))
            end

            result["success_url_list"].push(target_url)
          end
        rescue => err
          @logger.warn("Engine#crawl: crawl error")
          @logger.warn(err)

          result["fail_url_list"].push(target_url)
        end

        @logger.info("Engine#crawl: progress: total=#{url_list.size + result["success_url_list"].size + result["fail_url_list"].size}, success=#{result["success_url_list"].size}, fail=#{result["fail_url_list"].size}, remaining=#{url_list.size}")
      end

      result
    end

    def parse(url)
      @logger.debug("Engine#parse: start: url=#{url}")

      url_list = [url]
      result = { "success_url_list" => [], "fail_url_list" => [], "context" => {} }

      until url_list.empty? do
        @logger.debug("Engine#parse: until url_list.empty?")

        target_url = url_list.shift
        @logger.debug("Engine#parse: target_url=#{target_url}")

        begin
          next_links = parse_impl(target_url, result["context"])

          next_links.each do |next_link|
            url_list << next_link if (not url_list.include?(next_link)) && (not result["success_url_list"].include?(next_link)) && (not result["fail_url_list"].include?(next_link))
          end

          result["success_url_list"].push(target_url)
        rescue CrawlineError => err
          @logger.warn("Engine#parse: parse error")
          @logger.warn(err)

          result["fail_url_list"].push(target_url)
        end
      end

      result["context"]
    end

    def find_parser(url)
      @logger.debug("Engine#find_parser: start: url=#{url}")

      parser = @parsers.find do |url_pattern, clazz|
        url_pattern.match(url)
      end
      @logger.debug("Engine#find_parser: parser=#{parser}")

      if parser.nil?
        @logger.debug("Engine#find_parser: parser not found")
        raise ParserNotFoundError.new(url)
      end

      parser[1]
    end

    def data_to_json(data)
      json_data = Marshal.load(Marshal.dump(data))
      json_data["response_body"] = Base64.urlsafe_encode64(json_data["response_body"])
      json_data["downloaded_timestamp"] = json_data["downloaded_timestamp"].to_i

      json_data.to_json
    end

    def json_to_data(json_data)
      data = JSON.parse(json_data)
      data["response_body"] = Base64.urlsafe_decode64(data["response_body"])
      data["response_body"].force_encoding("US-ASCII")
      data["downloaded_timestamp"] = Time.at(data["downloaded_timestamp"], 0).getutc

      data
    end

    def get_latest_data_from_storage(url)
      @logger.debug("Engine#get_latest_data_from_storage: start: url=#{url}")

      s3_path = convert_url_to_s3_path(url)
      data = @repo.get_s3_object(s3_path + ".json")

      if not data.nil?
        json_to_data(data)
      else
        nil
      end
    end

    def download_or_redownload(url, parser, data)
      @logger.debug("Engine#download_or_redownload: start: url=#{url}, parser=#{parser}, data.nil?=#{data.nil?}")

      if data.nil?
        @logger.debug("Engine#download_or_redownload: download")

        sleep(@interval)
        new_data = @downloader.download_with_get(url)
      else
        parser_instance = parser.new(url, data)

        if parser_instance.redownload?
          @logger.debug("Engine#download_or_redownload: redownload")

          sleep(@interval)
          new_data = @downloader.download_with_get(url)
        else
          @logger.debug("Engine#download_or_redownload: skip")

          nil
        end
      end
    end

    def put_data_to_storage(url, data)
      @logger.debug("Engine#put_data_to_storage: start: url=#{url}, data=#{data.size if not data.nil?}")

      s3_path = convert_url_to_s3_path(url)
      @repo.put_s3_object(s3_path + ".json", data_to_json(data))
    end

    def list_cache_state(url)
      @logger.debug("Engine#list_cache_state: start: url=#{url}")

      url_list = [url]
      proccessed_url_list = []

      until url_list.empty? do
        target_url = url_list.shift
        @logger.debug("Engine#list_cache_state: target_url=#{target_url}")

        begin
          data = get_latest_data_from_storage(target_url)

          if data.nil?
            @logger.debug("Engine#list_cache_state: data not found: url=#{target_url}")
            yield(target_url, nil, nil)
          else
            parser = find_parser(target_url)
            if parser.nil?
              @logger.debug("Engine#list_cache_state: parser not found: url=#{target_url}")
              yield(target_url, data, nil)
            else
              parser_instance = parser.new(target_url, data)

              @logger.debug("Engine#list_cache_state: yield: url=#{target_url}")
              yield(target_url, data, parser_instance)

              if not parser_instance.related_links.nil?
                parser_instance.related_links.each do |next_link|
                  if not proccessed_url_list.include?(next_link)
                    url_list << next_link
                    proccessed_url_list << next_link
                  end
                end
              end
            end
          end
        rescue => err
          @logger.warn(err)
        end
      end
    end

    private

    def convert_url_to_s3_path(url)
      path = OpenSSL::Digest::SHA256.hexdigest(url)
      path = path[0..1] + "/" + path
    end

    def crawl_impl(url, context)
      # find parser
      parser = find_parser(url)

      # get cache
      latest_data = get_latest_data_from_storage(url)

      # download
      data = download_or_redownload(url, parser, latest_data)

      return [] if data.nil?

      # parse
      parser_instance = parser.new(url, data)
      parser_instance.parse(context)

      # save
      put_data_to_storage(url, data)

      # return next links
      related_links = parser_instance.related_links

      if not related_links.nil?
        related_links
      else
        []
      end
    end

    def parse_impl(url, context)
      # find parser
      parser = find_parser(url)

      # get cache
      data = get_latest_data_from_storage(url)

      if data.nil?
        raise ParseError.new("Cache data not found: url=#{url}")
      end

      # parse
      parser_instance = parser.new(url, data)
      parser_instance.parse(context)

      # return next links
      related_links = parser_instance.related_links

      if not related_links.nil?
        related_links
      else
        []
      end
    end
  end

  class BaseParser
    def redownload?
      raise "Not implemented."
    end

    def related_links
      raise "Not implemented."
    end

    def parse(context)
      raise "Not implemented."
    end
  end

  class CrawlineLogger
    @@logger = nil

    def self.get_logger
      if @@logger.nil?
        @@logger = Logger.new(STDOUT)

        @@logger.level = ENV["CRAWLINE_LOGGER_LEVEL"] if ENV.has_key?("CRAWLINE_LOGGER_LEVEL")
      end

      @@logger
    end
  end

  class CrawlineError < StandardError
  end

  class ParserNotFoundError < CrawlineError
    def initialize(url)
      super(url)
      @url = url
    end
  end

  class DownloadError < CrawlineError
  end

  class ParseError < CrawlineError
  end

end
