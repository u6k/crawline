require 'test_helper'

class RuleMatchRequestTest < ActiveSupport::TestCase

  test "match stock list page?" do
    request = {
      url: "https://kabuoji3.com/stock/?page=123",
      method: "GET"
    }

    stock_list_page_rule = StockListPageTestRule.new
    assert stock_list_page_rule.match_request?(request)

    stock_detail_page_rule = StockDetailPageTestRule.new
    assert_not stock_detail_page_rule.match_request?(request)

    stock_price_page_rule = StockPricePageTestRule.new
    assert_not stock_price_page_rule.match_request?(request)
  end

  test "match stock detail page?" do
    request = {
      url: "https://kabuoji3.com/stock/1234",
      method: "GET"
    }

    stock_list_page_rule = StockListPageTestRule.new
    assert_not stock_list_page_rule.match_request?(request)

    stock_detail_page_rule = StockDetailPageTestRule.new
    assert stock_detail_page_rule.match_request?(request)

    stock_price_page_rule = StockPricePageTestRule.new
    assert_not stock_price_page_rule.match_request?(request)
  end

  test "match stock price csv?" do
    request = {
      url: "https://kabuoji3.com/stock/file.php",
      method: "POST",
      parameters: {
        code: 1234,
        year: 2018
      }
    }

    stock_list_page_rule = StockListPageTestRule.new
    assert_not stock_list_page_rule.match_request?(request)

    stock_detail_page_rule = StockDetailPageTestRule.new
    assert_not stock_detail_page_rule.match_request?(request)

    stock_price_page_rule = StockPricePageTestRule.new
    assert stock_price_page_rule.match_request?(request)
  end

end

