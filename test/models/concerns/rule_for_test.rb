class StockListPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/\?page=([0-9]+)/.match(request[:url]) != nil)
  end

  def want_redownload?(latest_content)
    ((Time.zone.now - latest_content[:downloaded_timestamp]) > 86400) # 86400sec = 1day
  end

  def parse(downloaded_content)
    # parse
    result = { data: {}, related_requests: [] }

    result[:data][:page] = /https:\/\/kabuoji3\.com\/stock\/\?page=([0-9]+)/.match(downloaded_content[:url])[1].to_i

    doc = Nokogiri::HTML.parse(downloaded_content[:content], nil, "UTF-8")

    result[:data][:stocks] = doc.xpath("//table[@class='stock_table']/tbody/tr").map do |tr|
      {
        ticker_symbol: tr.at_xpath("td/a").text[0..3],
        company_name: tr.at_xpath("td/a").text[5..-1],
        market: tr.at_xpath("td[2]").text
      }
    end

    result[:related_requests] = doc.xpath("//table[@class='stock_table']/tbody/tr").map do |tr|
      {
        url: tr.at_xpath("td/a")["href"],
        method: "GET"
      }
    end

    result[:related_requests] += doc.xpath("//ul[@class='pager']/li/a").map do |a|
      {
        url: "https://kabuoji3.com/stock/" + a["href"],
        method: "GET"
      }
    end

    # check
    if not (result[:data][:page] == nil || result[:data][:page].integer?)
      raise "stock_list_page invalid. page not nil or integer. (page=#{result[:data][:page]})"
    end

    if result[:data][:stocks].length == 0
      raise "stock_list_page invalid. stocks not found."
    end

    result[:data][:stocks].each do |stock|
      if (not /[0-9]+/.match(stock[:ticker_symbol])) \
        || stock[:company_name].empty? \
        || stock[:market].empty?
        raise "stock_list_page invalid. stock invalid. (stock=#{stock})"
      end
    end

    result[:related_requests].each do |request|
      if (not /https:\/\/kabuoji3\.com\/stock\/([0-9]{4}\/|\?page=[0-9]+)/.match(request[:url]))
        raise "stock_list_page invalid. related_request invalid. (request=#{request})"
      end

      if request[:method] != "GET"
        raise "stock_list_page invalid. related_request invalid. (request=#{request})"
      end
    end

    # return
    result
  end

end

class StockDetailPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/([0-9]+)/.match(request[:url]) != nil)
  end

  def want_redownload?(latest_content)
    ((Time.zone.now - latest_content[:downloaded_timestamp]) > 86400) # 86400sec = 1day
  end

  def parse(downloaded_content)
    # parse
    result = { data: {}, related_requests: [] }

    doc = Nokogiri::HTML.parse(downloaded_content[:content], nil, "UTF-8")

    result[:data][:ticker_symbol] = doc.at_xpath("//h2[@class='base_box_ttl']/span[@class='jp']").text[0..3]
    result[:data][:company_name] = doc.at_xpath("//h2[@class='base_box_ttl']/span[@class='jp']").text[5..-1]

    if /https:\/\/kabuoji3\.com\/stock\/[0-9]{4}\/[0-9]+/.match(downloaded_content[:url])
      result[:data][:year] = /https:\/\/kabuoji3\.com\/stock\/[0-9]{4}\/([0-9]+)/.match(downloaded_content[:url])[1].to_i
    else
      result[:data][:year] = nil
    end

    result[:data][:all_years] = doc.xpath("//ul[@class='stock_yselect mt_10']/li/a").map do |a|
      if /^[0-9]+$/.match(a.text)
        a.text.to_i
      else
        nil
      end
    end
    result[:data][:all_years].compact!

    result[:data][:stock_prices] = doc.xpath("//table[@class='stock_table stock_data_table']//tr").map do |tr|
      if not tr.at_xpath("td[1]").nil?
        {
          date: Time.zone.parse(tr.at_xpath("td[1]").text),
          opening_price: tr.at_xpath("td[2]").text.to_i,
          high_price: tr.at_xpath("td[3]").text.to_i,
          low_price: tr.at_xpath("td[4]").text.to_i,
          close_price: tr.at_xpath("td[5]").text.to_i,
          turnover: tr.at_xpath("td[6]").text.to_i,
          adjustment_value: tr.at_xpath("td[7]").text.to_i
        }
      else
        nil
      end
    end
    result[:data][:stock_prices].compact!

    result[:related_requests] = doc.xpath("//ul[@class='stock_yselect mt_10']/li/a").map do |a|
      {
        url: a["href"],
        method: "GET"
      }
    end

    # check
    if not /[0-9]{4}/.match(result[:data][:ticker_symbol])
      raise "stock_detail_page invalid. ticker_symbol invalid. (ticker_symbol=#{result[:data][:ticker_symbol]})"
    end

    if result[:data][:company_name].empty?
      raise "stock_detail_page invalid. company_name empty."
    end

    if result[:data][:year] != nil && (not result[:data][:year].integer?)
      raise "stock_detail_page invalid. year not nil or integer. (year=#{result[:data][:year]})"
    end

    if result[:data][:all_years].length == 0
      raise "stock_detail_page invalid. all_years empty."
    end

    result[:data][:all_years].each do |year|
      if not year.integer?
        raise "stock_detail_page invalid. all_years invalid. (year=#{year})"
      end
    end

    if result[:data][:stock_prices].length == 0
      raise "stock_detail_page invalid. stock_prices empty."
    end

    result[:data][:stock_prices].each do |stock_price|
      if (not stock_price[:opening_price].integer?) \
        || (not stock_price[:high_price].integer?) \
        || (not stock_price[:low_price].integer?) \
        || (not stock_price[:close_price].integer?) \
        || (not stock_price[:turnover].integer?) \
        || (not stock_price[:adjustment_value].integer?)
        raise "stock_detail_page invalid. stock_price invalid. (stock_price=#{stock_price})"
      end
    end

    if result[:related_requests].length == 0
      raise "stock_detail_page invalid. related_requests empty."
    end

    result[:related_requests].each do |request|
      if (not /https:\/\/kabuoji3\.com\/stock\/[0-9]+\/([0-9]+\/)?/.match(request[:url])) \
        || request[:method] != "GET"
        raise "stock_detail_page invalid. related_requests invalid. (request=#{request})"
      end
    end

    # return
    result
  end

end

class StockPricePageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "POST" && request[:url] == "https://kabuoji3.com/stock/file.php" && /[0-9]+/.match(request[:request_parameters][:code]) != nil && /[0-9]+/.match(request[:request_parameters][:year]) != nil)
  end

  def want_redownload?(latest_content)
    if ((Time.zone.now - latest_content[:downloaded_timestamp]) <= 86400) # 86400sec = 1day
      return false
    end

    year = latest_content[:request_parameters][:year].to_i

    ((Time.zone.now.year - year) < 2)
  end

end

