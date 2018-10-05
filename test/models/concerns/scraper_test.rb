require 'test_helper'

class ScraperTest < ActiveSupport::TestCase

  test "find rule: stock list page" do
    Scraper.add_rule(StockListPageTestRule.new)
    Scraper.add_rule(StockDetailPageTestRule.new)
    Scraper.add_rule(StockPricePageTestRule.new)

    request = {
      url: "https://kabuoji3.com/stock/?page=123",
      method: "GET"
    }

    scraper = Scraper.new
    rule = scraper.find_rule(request)

    assert rule.instance_of?(StockListPageTestRule)
  end

  test "find rule: stock detail page" do
    Scraper.add_rule(StockListPageTestRule.new)
    Scraper.add_rule(StockDetailPageTestRule.new)
    Scraper.add_rule(StockPricePageTestRule.new)

    request = {
      url: "https://kabuoji3.com/stock/1234",
      method: "GET"
    }

    scraper = Scraper.new
    rule = scraper.find_rule(request)

    assert rule.instance_of?(StockDetailPageTestRule)
  end

  test "find rule: stock price page" do
    Scraper.add_rule(StockListPageTestRule.new)
    Scraper.add_rule(StockDetailPageTestRule.new)
    Scraper.add_rule(StockPricePageTestRule.new)

    request = {
      url: "https://kabuoji3.com/stock/file.php",
      method: "POST",
      request_parameters: {
        "code": "1234",
        "year": "2018"
      }
    }

    scraper = Scraper.new
    rule = scraper.find_rule(request)

    assert rule.instance_of?(StockPricePageTestRule)
  end

  test "find rule: not found" do
    Scraper.add_rule(StockListPageTestRule.new)
    Scraper.add_rule(StockDetailPageTestRule.new)
    Scraper.add_rule(StockPricePageTestRule.new)

    request = {
      url: "http://example.com",
      method: "GET"
    }

    scraper = Scraper.new
    rule = scraper.find_rule(request)

    assert_nil rule
  end

  test "get cache: not found" do
    flunk
  end

  test "get cache: get request" do
    flunk
  end

  test "get cache: post request" do
    flunk
  end

  test "get cache: binary content" do
    flunk
  end

end

