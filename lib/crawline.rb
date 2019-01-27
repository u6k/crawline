require "crawline/version"

require "aws-sdk-s3"

module Crawline

  class Downloader
    def initialize(user_agent)
      @user_agent = user_agent
    end

    def download_with_get(url)
      uri = URI(url)

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = @user_agent
      req["Accept"] = "*/*"

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if url.start_with?("https://")

      res = http.start do
        http.request(req)
      end

      case res
      when Net::HTTPSuccess
        res.body
      when Net::HTTPRedirection
        redirect_url = URI.join(url, res["location"]).to_s
        download_with_get(redirect_url)
      else
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
    def initialize(downloader, repo, rules)
      @downloader = downloader
      @repo = repo
      @rules = rules
    end

    def crwal(url)
      # select rule
      rule = select_rule(url)

      if rule.nil?
        return
      end

      # get cache
      s3_path = convert_url_to_s3_path(url)
      data = @repo.get_s3_object(s3_path + ".data")

      # download
      new_data = 
        if data.nil?
          new_data = @downloader.download_with_get(url)
        else
          rule_instance = rule.new(url, data)

          if rule_instance.redownload?
            new_data = @downloader.download_with_get(url)
          else
            nil
          end
        end

      if new_data.nil?
        return
      end

      # validate
      rule_instance = rule.new(url, new_data)

      if not rule_instance.valid?
        return
      end

      # save
      @repo.put_s3_object(s3_path + ".data", new_data)

      # crawl next links
      rule_instance.related_links.each do |url|
        crawl(url)
      end
    end

    def select_rule(url)
      rule = @rules.find do |url_pattern, clazz|
        url_pattern.match(url)
      end

      (rule.nil? ? nil : rule[1])
    end

    def convert_url_to_s3_path(url)
      OpenSSL::Digest::SHA256.hexdigest(url)
    end
  end

  class BaseRule
    def redownload?
      raise "Not implemented."
    end

    def valid?
      raise "Not implemented."
    end

    def related_links
      raise "Not implemented."
    end

    def parse
      raise "Not implemented."
    end
  end

end
