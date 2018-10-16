require 'test_helper'
require "webmock/minitest"

class ScraperDownloadTest < ActiveSupport::TestCase

  def setup
    stub_request(:get, "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html").to_return(
      status: 200,
      headers: { "server" => "nginx", "content-type" => "text/plain" },
      body: File.open("test/fixtures/files/blog_page.html").read
    )
  end

  test "download: get request" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html",
      "method" => "GET"
    }

    # execute
    scraper = Scraper.new
    response = scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/plain"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post request" do
    flunk
  end

  test "download: redirect" do
    flunk
  end

  test "download: not modified" do
    flunk
  end

  test "download: not found" do
    flunk
  end

  test "download: internal server error" do
    flunk
  end

  test "download: timeout" do
    flunk
  end

end

