class ContentNotFoundError < StandardError; end

class ContentOtherError < StandardError; end

class ContentTimeoutError < StandardError; end

class Scraper
  extend ActiveSupport::Concern

  attr_accessor :rules, :download_interval, :retry_limit
  
  def initialize()
    @rules = []
    @download_interval = 1
    @retry_limit = 5
  end

  def find_rule(request)
    rule = @rules.find { |rule| rule.match_request?(request) }
  end

  def download(request)
    if request["method"] == "GET"
      download_with_get(request["url"], request["headers"], 0)
    elsif request["method"] == "POST"
      download_with_post(request["url"], request["headers"], request["parameters"], 0)
    else
      Rails.logger.warn "download: method is not GET or POST. method=#{request["method"]}"
    end
  end

  private

  def download_with_get(url, headers, timeout_count)
    sleep(@download_interval) # FIXME

    uri = URI(url)

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "curl/7.54.0" # FIXME
    req["Accept"] = "*/*" # FIXME
    if not headers.nil?
      headers.each do |name, val|
        req[name] = val
      end
    end

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") do |http|
      http.request(req)
    end

    if res.code == "200"
      response = {
        "headers" => {},
        "content" => res.body
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    elsif res.code == "201" || res.code == "301" || res.code == "302" || res.code == "303"
      redirect_url = URI::join(url, res["Location"]).to_s

      download_with_get(redirect_url, headers, 0)
    elsif res.code == "304"
      response = {
        "headers" => {},
        "content" => nil
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    elsif res.code == "404"
      raise ContentNotFoundError
    else
      # FIXME
      Rails.logger.warn "download_with_get: invalid status code: url=#{url}, code=#{res.code}"
      raise ContentOtherError
    end
  rescue Net::OpenTimeout => e
    timeout_count += 1
    Rails.logger.warn "download_with_get: timeout: url=#{url}, timeout_count=#{timeout_count}"

    if timeout_count > @retry_limit
      raise ContentTimeoutError
    end

    download_with_get(url, headers, timeout_count)
  end

  def download_with_post(url, headers, data, timeout_count)
    sleep(@download_interval) # FIXME

    uri = URI(url)

    req = Net::HTTP::Post.new(uri)
    req["User-Agent"] = "curl/7.54.0" # FIXME
    req["Accept"] = "*/*" # FIXME
    if not headers.nil?
      headers.each do |name, val|
        req[name] = val
      end
    end
    req.set_form_data(data)

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") do |http|
      http.request(req)
    end

    if res.code == "200"
      response = {
        "headers" => {},
        "content" => res.body
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    elsif res.code == "201" || res.code == "301" || res.code == "302" || res.code == "303"
      redirect_url = URI::join(url, res["Location"]).to_s

      download_with_get(redirect_url, headers, 0)
    elsif res.code == "304"
      response = {
        "headers" => {},
        "content" => nil
      }
      res.each do |name, val|
        response["headers"][name] = val
      end

      response
    elsif res.code == "404"
      raise ContentNotFoundError
    else
      # FIXME
      Rails.logger.warn "download_with_post: invalid status code: url=#{url}, code=#{res.code}"
      raise ContentOtherError
    end
  rescue Net::OpenTimeout => e
    timeout_count += 1
    Rails.logger.warn "download_with_post: timeout: url=#{url}, timeout_count=#{timeout_count}"

    if timeout_count > @retry_limit
      raise ContentTimeoutError
    end

    download_with_post(url, headers, data, timeout_count)
  end

end

