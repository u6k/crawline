class StockListPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/\?page=([0-9]+)/.match(request[:url]) != nil)
  end

end

class StockDetailPageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "GET" && /https:\/\/kabuoji3\.com\/stock\/([0-9]+)/.match(request[:url]) != nil)
  end

end

class StockPricePageTestRule < BaseRule

  def match_request?(request)
    (request[:method] == "POST" && request[:url] == "https://kabuoji3.com/stock/file.php" && /[0-9]+/.match(request[:parameters][:code]) != nil && /[0-9]+/.match(request[:parameters][:year]) != nil)
  end

end

