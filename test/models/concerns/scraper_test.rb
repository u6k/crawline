require 'test_helper'

class ScraperTest < ActiveSupport::TestCase

  def setup
    @scraper = Scraper.new

    @scraper.rules << StockListPageTestRule.new
    @scraper.rules << StockDetailPageTestRule.new
    @scraper.rules << StockPricePageTestRule.new
  end

  test "find rule: stock list page" do
    request = {
      url: "https://kabuoji3.com/stock/?page=123",
      method: "GET"
    }

    rule = @scraper.find_rule(request)

    assert rule.instance_of?(StockListPageTestRule)
  end

  test "find rule: stock detail page" do
    request = {
      url: "https://kabuoji3.com/stock/1234",
      method: "GET"
    }

    rule = @scraper.find_rule(request)

    assert rule.instance_of?(StockDetailPageTestRule)
  end

  test "find rule: stock price page" do
    request = {
      url: "https://kabuoji3.com/stock/file.php",
      method: "POST",
      request_parameters: {
        "code": "1234",
        "year": "2018"
      }
    }

    rule = @scraper.find_rule(request)

    assert rule.instance_of?(StockPricePageTestRule)
  end

  test "find rule: not found" do
    request = {
      url: "http://example.com",
      method: "GET"
    }

    rule = @scraper.find_rule(request)

    assert_nil rule
  end

end

