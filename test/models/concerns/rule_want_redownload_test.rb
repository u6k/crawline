require 'test_helper'
require 'timecop'

class RuleWantRedownloadTest < ActiveSupport::TestCase

  test "want re-download: stock list page" do
    latest_content = {
      url: "https://kabuoji3.com/stock/?page=1",
      method: "GET",
      response_headers: {
        "server": "nginx",
        "date": "Mon, 01 Oct 2018 11:53:48 GMT",
        "content-type": "text/html",
        "x-powered-by": "PHP/5.2.17"
      },
      content: File.open("test/fixtures/files/stock_list_page_1.html").read,
      downloaded_timestamp: Time.zone.local(2018, 10, 1, 20, 53, 48)
    }

    stock_list_page_rule = StockListPageTestRule.new

    # Custom rule: one day has not passed since the last download, do not re-download.
    Timecop.freeze(Time.zone.local(2018, 10, 2, 20, 53, 48)) do
      assert_not stock_list_page_rule.want_redownload?(latest_content)
    end

    Timecop.freeze(Time.zone.local(2018, 10, 2, 20, 53, 49)) do
      assert stock_list_page_rule.want_redownload?(latest_content)
    end
  end

  test "want re-download: stock detail page" do
    latest_content = {
      url: "https://kabuoji3.com/stock/1301/",
      method: "GET",
      response_headers: {
        "server": "nginx",
        "date": "Wed, 03 Oct 2018 04:08:05 GMT",
        "content-type": "text/html",
        "x-powered-by": "PHP/5.2.17"
      },
      content: File.open("test/fixtures/files/stock_detail_1301.html").read,
      downloaded_timestamp: Time.zone.local(2018, 10, 3, 11, 8, 5)
    }

    stock_detail_page_rule = StockDetailPageTestRule.new

    # Custom rule: One day has not passed since the last download, do not re-download
    Timecop.freeze(Time.zone.local(2018, 10, 4, 11, 8, 5)) do
      assert_not stock_detail_page_rule.want_redownload?(latest_content)
    end

    Timecop.freeze(Time.zone.local(2018, 10, 4, 11, 8, 6)) do
      assert stock_detail_page_rule.want_redownload?(latest_content)
    end
  end

  test "want re-download: stock price csv" do
    latest_content = {
      url: "https://kabuoji3.com/stock/file.php",
      method: "POST",
      request_parameters: {
        "code": "1301",
        "year": "2018"
      },
      response_headers: {
        "server": "nginx",
        "content-type": "application/force-download",
        "content-length": "10329",
        "x-powered-by": "PHP/5.2.17",
        "content-disposition": "attachment; filename=\"1301_2018.csv\""
      },
      content: File.open("test/fixtures/files/stock_price_1301_2018.csv").read,
      downloaded_timestamp: Time.zone.local(2018, 10, 1, 21, 21, 54)
    }

    stock_price_page_rule = StockPricePageTestRule.new

    # Custom rule: One day has not passed since the last download, do not re-download
    Timecop.freeze(Time.zone.local(2018, 10, 2, 21, 21, 54)) do
      assert_not stock_price_page_rule.want_redownload?(latest_content)
    end

    Timecop.freeze(Time.zone.local(2018, 10, 2, 21, 21, 55)) do
      assert stock_price_page_rule.want_redownload?(latest_content)
    end

    # Custom rule: 2 years has passed since the contents year, do not re-download
    Timecop.freeze(Time.zone.local(2019, 12, 31, 23, 59, 59)) do
      assert stock_price_page_rule.want_redownload?(latest_content)
    end

    Timecop.freeze(Time.zone.local(2020, 1, 1, 0, 0, 0)) do
      assert_not stock_price_page_rule.want_redownload?(latest_content)
    end
  end

end

