require "crawline/version"

require "aws-sdk-s3"

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
      end
      @logger.debug("Downloader#download_with_get: request end: response=#{res}")

      case res
      when Net::HTTPSuccess
        @logger.debug("Downloader#download_with_get: status is success")
        res.body
      when Net::HTTPRedirection
        @logger.debug("Downloader#download_with_get: status is redirection")
        redirect_url = URI.join(url, res["location"]).to_s
        download_with_get(redirect_url)
      else
        @logger.debug("Downloader#download_with_get: status is else: code=#{res.code}, #{res.message}")
        raise "#{res.code} #{res.message}"
      end
    end
  end

  class ResourceRepository
    def initialize(access_key, secret_key, region, bucket, endpoint, force_path_style)
      Aws.config.update({
        region: region,
        credentials: Aws::Credentials.new(access_key, secret_key)
      })
      s3 = Aws::S3::Resource.new(endpoint: endpoint, force_path_style: force_path_style)

      @bucket = s3.bucket(bucket)
      @bucket.create if not @bucket.exists?
    end

    def put_s3_object(file_name, data)
      obj_original = @bucket.object(file_name + ".latest")
      obj_original.put(body: data)

      obj_backup = @bucket.object(file_name + "." + Time.now.to_i.to_s)
      obj_backup.put(body: data)
    end

    def get_s3_object(file_name)
      object = @bucket.object(file_name + ".latest")

      begin
        data = object.get.body.read(object.size)
      rescue Aws::S3::Errors::NoSuchKey
        data = nil
      end

      data
    end

    def exists_s3_object?(file_name)
      (not get_s3_object(file_name).nil?)
    end

    def remove_s3_objects
      @bucket.objects.batch_delete!
    end
  end

  class Engine
    def initialize(downloader, repo, parsers)
      raise ArgumentError, "downloader is nil." if downloader.nil?
      raise ArgumentError, "repo is nil." if repo.nil?
      raise ArgumentError, "parsers is nil." if parsers.nil?

      raise TypeError, "downloader is not Crawline::Downloader." if not downloader.is_a?(Crawline::Downloader)
      raise TypeError, "repo is not Crawline::ResourceRepository." if not repo.is_a?(Crawline::ResourceRepository)
      parsers.each do |url_pattern, parser|
        raise TypeError, "parsers is not Hash<Regexp, Parser>." if not url_pattern.is_a?(Regexp)
        # FIXME: Check BaseParser subclass ... raise TypeError, "parsers is not Hash<Regexp, Parser>." if not parser.is_a?(Crawline::BaseParser)
      end

      @downloader = downloader
      @repo = repo
      @parsers = parsers
    end

    def crawl(url)
      url_list = [url]
      result = { "success_url_list" => [], "fail_url_list" => [] }

      until url_list.empty? do
        target_url = url_list.shift

        begin
          next_links = crawl_impl(target_url)

          if not next_links.nil?
            next_links.each do |next_link|
              url_list << next_link if (not url_list.include?(next_link)) && (not result["success_url_list"].include?(next_link)) && (not result["fail_url_list"].include?(next_link))
            end

            result["success_url_list"].push(target_url)
          end
        rescue
          # FIXME
          result["fail_url_list"].push(target_url)
        end
      end

      result
    end

    def parse(url)
      url_list = [url]
      result = { "success_url_list" => [], "fail_url_list" => [], "context" => {} }

      until url_list.empty? do
        target_url = url_list.shift

        begin
          next_links = parse_impl(target_url, result["context"])

          if not next_links.nil?
            next_links.each do |next_link|
              url_list << next_link if (not url_list.include?(next_link)) && (not result["success_url_list"].include?(next_link)) && (not result["fail_url_list"].include?(next_link))
            end

            result["success_url_list"].push(target_url)
          end
        rescue
          # FIXME
          result["fail_url_list"].push(target_url)
        end
      end

      result["context"]
    end

    def select_parser(url)
      parser = @parsers.find do |url_pattern, clazz|
        url_pattern.match(url)
      end

      (parser.nil? ? nil : parser[1])
    end

    def get_latest_data_from_storage(url)
      s3_path = convert_url_to_s3_path(url)
      data = @repo.get_s3_object(s3_path + ".data")
    end

    def download_or_redownload(url, parser, data)
      if data.nil?
        new_data = @downloader.download_with_get(url)
      else
        parser_instance = parser.new(url, data)

        if parser_instance.redownload?
          new_data = @downloader.download_with_get(url)
        else
          nil
        end
      end
    end

    def put_data_to_storage(url, data)
      s3_path = convert_url_to_s3_path(url)
      @repo.put_s3_object(s3_path + ".data", data)
    end

    private

    def convert_url_to_s3_path(url)
      OpenSSL::Digest::SHA256.hexdigest(url)
    end

    def crawl_impl(url)
      # select parser
      parser = select_parser(url)

      if parser.nil?
        # TODO
        raise "Parser not found."
      end

      # get cache
      latest_data = get_latest_data_from_storage(url)

      # download
      new_data = download_or_redownload(url, parser, latest_data)

      if new_data.nil?
        # TODO
        return nil
      end

      # validate
      parser_instance = parser.new(url, new_data)

      if not parser_instance.valid?
        # TODO
        raise "Downloaded data invalid."
      end

      # save
      put_data_to_storage(url, new_data)

      # return next links
      parser_instance.related_links
    end

    def parse_impl(url, context)
      # select parser
      parser = select_parser(url)

      if parser.nil?
        # TODO
        raise "Parser not found."
      end

      # get cache
      data = get_latest_data_from_storage(url)

      # parse
      parser_instance = parser.new(url, data)
      parser_instance.parse(context)

      # return next links
      parser_instance.related_links
    end
  end

  class BaseParser
    def redownload?
      raise "Not implemented."
    end

    def valid?
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

end
