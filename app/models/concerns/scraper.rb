class Scraper
  extend ActiveSupport::Concern

  attr_accessor :download_interval
  
  @@rules = []
  
  def self.add_rule(rule)
    @@rules << rule
  end

  def initialize()
    @download_interval = 1
  end

  def find_rule(request)
    rule = @@rules.find { |rule| rule.match_request?(request) }
  end

  def download(request)
    if request["method"] == "GET"
      download_with_get(request["url"])
    elsif request["method"] == "POST"
      download_with_post(request["url"], request["parameters"])
    else
      Rails.logger.warn "download: method is not GET or POST. method=#{request["method"]}"
    end
  end

  private

  def download_with_get(url)
    uri = URI(url)

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "curl/7.54.0" # FIXME
    req["Accept"] = "*/*" # FIXME

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") do |http|
      http.request(req)
    end

    sleep(@download_interval) # FIXME

    if res.code == "200"
      response = {
        "headers" => {},
        "content" => res.body
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    else
      # FIXME
      Rails.logger.warn "download_with_get: status code not 200 ok: url=#{url}, code=#{res.code}"
      nil
    end
  end

  def download_with_post(url, data)
    uri = URI(url)

    req = Net::HTTP::Post.new(uri)
    req["User-Agent"] = "curl/7.54.0" # FIXME
    req["Accept"] = "*/*" # FIXME
    req.set_form_data(data)

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") do |http|
      http.request(req)
    end

    sleep(@download_interval) # FIXME

    if res.code == "200"
      response = {
        "headers" => {},
        "content" => res.body
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    else
      # FIXME
      Rails.logger.warn "download_with_post: status code not 200 ok: url=#{url}, data=#{data}, code=#{res.code}"
      nil
    end
  end

end

