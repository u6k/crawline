class Scraper
  extend ActiveSupport::Concern
  
  @@rules = []
  
  def self.add_rule(rule)
    @@rules << rule
  end

  def find_rule(request)
    rule = @@rules.find { |rule| rule.match_request?(request) }
  end

  def download(request)
    download_with_get(request["url"])
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

    sleep(1) # FIXME

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

end

