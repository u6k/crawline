class BaseRule

  def match_request?(request)
    raise "Not implemented."
  end

end

class StockListPageTestRule < BaseRule

end

class StockDetailPageTestRule < BaseRule

end

class StockProcePageTestRule < BaseRule

end

