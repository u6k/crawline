require 'test_helper'
require "webmock/minitest"

class ScraperDownloadTest < ActiveSupport::TestCase

  def setup
    # stub request
    stub_request(:get, "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html").to_return(
      status: 200,
      headers: {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      body: File.open("test/fixtures/files/blog_page.html").read
    )

    stub_request(:post, "https://blog.u6k.me/tags/").with(body: { "tag": "Docker" }).to_return(
      status: 200,
      headers: {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      body: File.open("test/fixtures/files/blog_tags.html").read
    )

    # stub redirect
    stub_request(:get, "https://blog.u6k.me/redirect/201.html").to_return(
      status: 201,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:get, "https://blog.u6k.me/redirect/301.html").to_return(
      status: 301,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:get, "https://blog.u6k.me/redirect/302.html").to_return(
      status: 302,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:get, "https://blog.u6k.me/redirect/303.html").to_return(
      status: 303,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:post, "https://blog.u6k.me/redirect/").with(body: { "code": "201" }).to_return(
      status: 201,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:post, "https://blog.u6k.me/redirect/").with(body: { "code": "301" }).to_return(
      status: 301,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:post, "https://blog.u6k.me/redirect/").with(body: { "code": "302" }).to_return(
      status: 302,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    stub_request(:post, "https://blog.u6k.me/redirect/").with(body: { "code": "303" }).to_return(
      status: 303,
      headers: {
        "Location" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html"
      }
    )

    # build Scraper
    @scraper = Scraper.new
    @scraper.download_interval = 0.001
  end

  test "download: get request" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html",
      "method" => "GET"
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post request" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/tags/",
      "method" => "POST",
      "parameters" => {
        "tag" => "Docker"
      }
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_tags.html").read
    }

    assert_equal response, expected_response
  end

  test "download: get redirect: 301 Moved Permanently" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/301.html",
      "method" => "GET"
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: get redirect: 302 Fuond" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/302.html",
      "method" => "GET"
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: get redirect: 303 See Other" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/303.html",
      "method" => "GET"
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post redirect: 201 Created" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/",
      "method" => "POST",
      "parameters" => {
        "code" => "201"
      }
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post redirect: 301 Moved Permanently" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/",
      "method" => "POST",
      "parameters" => {
        "code" => "301"
      }
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post redirect: 302 Found" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/",
      "method" => "POST",
      "parameters" => {
        "code" => "302"
      }
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: post redirect: 303 See Other" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/redirect/",
      "method" => "POST",
      "parameters" => {
        "code" => "303"
      }
    }

    # execute
    response = @scraper.download(request)

    # check
    expected_response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-3c1a9",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:13:51 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "D330:06AC:5AEE2DB:75C2949:5BBC1A97",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 03:03:51 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18024-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539054232.662714,VS0,VE244",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "fd4a9481023f92db718dfa8a1986786bb792bb60",
        "content-length" => "246185"
      },
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal response, expected_response
  end

  test "download: get not modified" do
    flunk
  end

  test "download: post not modified" do
    flunk
  end

  test "download: get not found" do
    flunk
  end

  test "download: post not found" do
    flunk
  end

  test "download: get internal server error" do
    flunk
  end

  test "download: post internal server error" do
    flunk
  end

  test "download: get timeout" do
    flunk
  end

  test "download: post timeout" do
    flunk
  end

end

