require "crawline/version"

module Crawline

  class Downloader
    def self.download_with_get(url)
      uri = URI(url)

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "curl/7.54.0"
      req["Accept"] = "*/*"

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") do |http|
        http.request(req)
      end

      case res
      when Net::HTTPSuccess
        res.body
      when Net::HTTPRedirection
        download_with_get(res["location"])
      else
        raise "#{res.code} #{res.message}"
      end
    end
  end

  class ResourceRepository
    def self.put_s3_object(bucket, file_name, data)
      # upload
      obj_original = bucket.object(file_name)
      obj_original.put(body: data)

      obj_backup = bucket.object(file_name + ".bak_" + DateTime.now.strftime("%Y%m%d-%H%M%S"))
      obj_backup.put(body: data)

      { original: obj_original.key, backup: obj_backup.key }
    end

    def self.get_s3_object(bucket, file_name)
      # download
      object = bucket.object(file_name)
      data = object.get.body.read(object.size)
    end
  end

end
