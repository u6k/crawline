class StockListPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/\?page=([0-9]+)/.match(request[:url]) != nil)
  end

  def want_redownload?(latest_content)
    ((Time.zone.now - latest_content[:downloaded_timestamp]) > 86400) # 86400sec = 1day
  end

end

class StockDetailPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/([0-9]+)/.match(request[:url]) != nil)
  end

  def want_redownload?(latest_content)
    ((Time.zone.now - latest_content[:downloaded_timestamp]) > 86400) # 86400sec = 1day
  end

end

class StockPricePageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "POST" && request[:url] == "https://kabuoji3.com/stock/file.php" && /[0-9]+/.match(request[:request_parameters][:code]) != nil && /[0-9]+/.match(request[:request_parameters][:year]) != nil)
  end

  def want_redownload?(latest_content)
    ((Time.zone.now - latest_content[:downloaded_timestamp]) > 86400) # 86400sec = 1day
  end

end

