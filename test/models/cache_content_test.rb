require 'test_helper'

class CacheContentTest < ActiveSupport::TestCase

  def setup
    WebMock.disable_net_connect!(allow: "s3")

    # save blog_page
    request = {
      "url" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html",
      "method" => "GET"
    }

    response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/plain"
      }
    }

    content = "blog_page_1"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 1)
    cache_content.save!

    content = "blog_page_2"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 2)
    cache_content.save!

    response = {
      "headers" => {
        "server" => "GitHub.com",
        "content-type" => "text/html; charset=utf-8",
        "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
        "etag" => "5b48dca2-58fd",
        "access-control-allow-origin" => "*",
        "expires" => "Tue, 09 Oct 2018 03:01:56 GMT",
        "cache-control" => "max-age=600",
        "x-github-request-id" => "A482:358A:102F627:160CADB:5BBC17CC",
        "accept-ranges" => "bytes",
        "date" => "Tue, 09 Oct 2018 02:51:57 GMT",
        "via" => "1.1 varnish",
        "age" => "0",
        "x-served-by" => "cache-sin18022-SIN",
        "x-cache" => "MISS",
        "x-cache-hits" => "0",
        "x-timer" => "S1539053517.804919,VS0,VE237",
        "vary" => "Accept-Encoding",
        "x-fastly-request-id" => "0f079439d28fe3ae5e03de983785f513eb668167",
        "content-length" => "22781"
      }
    }

    content = File.open("test/fixtures/files/blog_page.html").read
    content_version = Time.zone.local(2018, 10, 9, 11, 1, 56).to_i

    cache_content = CacheContent.new_from_request_and_response(request, response, content, content_version)
    cache_content.save!

    # save blog tags
    request = {
      "url" => "https://kabuoji3.com/tags/",
      "method" => "POST",
      "parameters" => {
        "tag" => "Docker"
      }
    }

    response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/plain"
      }
    }

    content = "blog_tags_1"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 1)
    cache_content.save!

    content = "blog_tags_2"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 2)
    cache_content.save!

    response = {
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
      }
    }

    content = File.open("test/fixtures/files/blog_tags.html").read
    content_version = Time.zone.local(2018, 10, 9, 11, 3, 51).to_i

    cache_content = CacheContent.new_from_request_and_response(request, response, content, content_version)
    cache_content.save!

    # save binary
    request = {
      "url" => "http://gravatar.com/avatar/7cbe65037b17a6ee6711ce18b1e97638",
      "method" => "GET"
    }

    response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/plain"
      }
    }

    content = "binary_1"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 1)
    cache_content.save!

    content = "binary_2"

    cache_content = CacheContent.new_from_request_and_response(request, response, content, 2)
    cache_content.save!

    response = {
      "headers" => {
        "Server" => "nginx",
        "Date" => "Tue, 09 Oct 2018 03:15:49 GMT",
        "Content-Type" => "image/png",
        "Content-Length" => "10012",
        "Connection" => "keep-alive",
        "Last-Modified" => "Thu, 29 Dec 2016 10:21:55 GMT",
        "Link" => "<http://www.gravatar.com/avatar/7cbe65037b17a6ee6711ce18b1e97638>; rel=\"canonical\"",
        "Content-Disposition" => "inline; filename=\"7cbe65037b17a6ee6711ce18b1e97638.png\"",
        "Access-Control-Allow-Origin" => "*",
        "X-Varnish" => "1030785095 825725510",
        "Via" => "1.1 varnish-v4",
        "Accept-Ranges" => "bytes",
        "Expires" => "Tue, 09 Oct 2018 03:20:49 GMT",
        "Cache-Control" => "max-age=300",
        "Source-Age" => "4252"
      }
    }

    content = File.open("test/fixtures/files/gravatar.png").read
    content_version = Time.zone.local(2018, 10, 9, 11, 3, 15).to_i

    cache_content = CacheContent.new_from_request_and_response(request, response, content, content_version)
    cache_content.save!
  end

  test "save cache: 1 cache" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/001.html",
      "method" => "GET"
    }

    response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/html; charset=utf-8",
        "date" => "Tue, 09 Oct 2018 02:51:57 GMT"
      }
    }

    content = File.open("test/fixtures/files/blog_page.html").read

    # execute
    cache_content = CacheContent.new_from_request_and_response(request, response, content, 123)
    cache_content.save!

    # check
    cache_contents = CacheContent.where(cache_hash: "1917509773f0d090635b1b513627c6e4774acf4b093934255004e77320ea1270")

    assert_equal 1, cache_contents.length

    cache_content = cache_contents[0]

    assert_equal "1917509773f0d090635b1b513627c6e4774acf4b093934255004e77320ea1270", cache_content.cache_hash
    assert_equal 123, cache_content.content_version

    downloaded_content_meta = nil
    downloaded_content = nil
    SevenZipRuby::Reader.open(StringIO.new(cache_content.content.download)) do |szr|
      szr.entries.each do |entry|
        if entry.path.end_with?(".meta")
          downloaded_content_meta = szr.extract_data(entry)
        elsif entry.path.end_with?(".bin")
          downloaded_content = szr.extract_data(entry)
        end
      end
    end
    downloaded_content_hash = OpenSSL::Digest::SHA256.hexdigest(downloaded_content)

    expected_content_meta = {
      "request" => request,
      "response" => response,
      "cached_timestamp" => 123
    }.to_json
    expected_content_hash = OpenSSL::Digest::SHA256.hexdigest(content)

    assert_equal expected_content_meta, downloaded_content_meta
    assert_equal expected_content_hash, downloaded_content_hash
    # FIXME assert_equal content, downloaded_content
  end

  test "save cache: cache_version not setting(default)" do
    # setup
    started_timestamp = Time.zone.now.utc.to_i

    request = {
      "url" => "https://blog.u6k.me/001.html",
      "method" => "GET"
    }

    response = {
      "headers" => {
        "server" => "nginx",
        "content-type" => "text/html; charset=utf-8",
        "date" => "Tue, 09 Oct 2018 02:51:57 GMT"
      }
    }

    content = File.open("test/fixtures/files/blog_page.html").read

    # execute
    cache_content = CacheContent.new_from_request_and_response(request, response, content)
    cache_content.save!

    # check
    cache_contents = CacheContent.where(cache_hash: "1917509773f0d090635b1b513627c6e4774acf4b093934255004e77320ea1270")

    assert_equal 1, cache_contents.length

    cache_content = cache_contents[0]

    assert started_timestamp <= cache_content.content_version
  end

  test "find cache: not found" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/foo/bar/boo.html",
      "method" => "GET"
    }

    # execute
    cache_content = CacheContent.find_by_request(request)

    # check
    assert_nil cache_content
  end

  test "find cache: get request" do
    # setup
    request = {
      "url" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html",
      "method" => "GET"
    }

    # execute
    cache_content = CacheContent.find_by_request(request)

    # check
    expected_cache = {
      "request" => {
        "url" => "https://blog.u6k.me/2018/06/09/my-development-environment-and-deploy-workflow.html",
        "method" => "GET"
      },
      "response" => {
        "headers" => {
          "server" => "GitHub.com",
          "content-type" => "text/html; charset=utf-8",
          "last-modified" => "Fri, 13 Jul 2018 17:08:50 GMT",
          "etag" => "5b48dca2-58fd",
          "access-control-allow-origin" => "*",
          "expires" => "Tue, 09 Oct 2018 03:01:56 GMT",
          "cache-control" => "max-age=600",
          "x-github-request-id" => "A482:358A:102F627:160CADB:5BBC17CC",
          "accept-ranges" => "bytes",
          "date" => "Tue, 09 Oct 2018 02:51:57 GMT",
          "via" => "1.1 varnish",
          "age" => "0",
          "x-served-by" => "cache-sin18022-SIN",
          "x-cache" => "MISS",
          "x-cache-hits" => "0",
          "x-timer" => "S1539053517.804919,VS0,VE237",
          "vary" => "Accept-Encoding",
          "x-fastly-request-id" => "0f079439d28fe3ae5e03de983785f513eb668167",
          "content-length" => "22781"
        }
      },
      "cached_timestamp" => Time.zone.local(2018, 10, 9, 11, 1, 56).to_i,
      "content" => File.open("test/fixtures/files/blog_page.html").read
    }

    assert_equal "6b44e4173ba3995850ac8d5a251fc7a6a8184925c482bbc6053ab66f99f6d2ef", cache_content.cache_hash
    assert_equal 1539082916, cache_content.content_version
    # FIXME assert_equal expected_cache, cache_content.to_cache
    cache = cache_content.to_cache
    assert_equal expected_cache["request"], cache["request"]
    assert_equal expected_cache["response"], cache["response"]
    assert_equal expected_cache["cached_timestamp"], cache["cached_timestamp"]
    assert_equal OpenSSL::Digest::SHA256.hexdigest(expected_cache["content"]), OpenSSL::Digest::SHA256.hexdigest(cache["content"])
  end

  test "find cache: post request" do
    # setup
    request = {
      "url" => "https://kabuoji3.com/tags/",
      "method" => "POST",
      "parameters" => {
        "tag" => "Docker"
      }
    }

    # execute
    cache_content = CacheContent.find_by_request(request)

    # check
    expected_cache = {
      "request" => {
        "url" => "https://kabuoji3.com/tags/",
        "method" => "POST",
        "parameters" => {
          "tag" => "Docker"
        }
      },
      "response" => {
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
        }
      },
      "cached_timestamp" => Time.zone.local(2018, 10, 9, 11, 3, 51).to_i,
      "content" => File.open("test/fixtures/files/blog_tags.html").read
    }

    assert_equal "91714a83e2f23f380964823d2e2bbd5b3fd5218e43ac36abf2602ba531b8b6e0", cache_content.cache_hash
    assert_equal 1539083031, cache_content.content_version
    # FIXME assert_equal expected_cache, cache_content.to_cache
    cache = cache_content.to_cache
    assert_equal expected_cache["request"], cache["request"]
    assert_equal expected_cache["response"], cache["response"]
    assert_equal expected_cache["cached_timestamp"], cache["cached_timestamp"]
    assert_equal OpenSSL::Digest::SHA256.hexdigest(expected_cache["content"]), OpenSSL::Digest::SHA256.hexdigest(cache["content"])
  end

  test "find cache: binary content" do
    # setup
    request = {
      "url" => "http://gravatar.com/avatar/7cbe65037b17a6ee6711ce18b1e97638",
      "method" => "GET"
    }

    # execute
    cache_content = CacheContent.find_by_request(request)

    # check
    expected_cache = {
      "request" => {
        "url" => "http://gravatar.com/avatar/7cbe65037b17a6ee6711ce18b1e97638",
        "method" => "GET"
      },
      "response" => {
        "headers" => {
          "Server" => "nginx",
          "Date" => "Tue, 09 Oct 2018 03:15:49 GMT",
          "Content-Type" => "image/png",
          "Content-Length" => "10012",
          "Connection" => "keep-alive",
          "Last-Modified" => "Thu, 29 Dec 2016 10:21:55 GMT",
          "Link" => "<http://www.gravatar.com/avatar/7cbe65037b17a6ee6711ce18b1e97638>; rel=\"canonical\"",
          "Content-Disposition" => "inline; filename=\"7cbe65037b17a6ee6711ce18b1e97638.png\"",
          "Access-Control-Allow-Origin" => "*",
          "X-Varnish" => "1030785095 825725510",
          "Via" => "1.1 varnish-v4",
          "Accept-Ranges" => "bytes",
          "Expires" => "Tue, 09 Oct 2018 03:20:49 GMT",
          "Cache-Control" => "max-age=300",
          "Source-Age" => "4252"
        }
      },
      "cached_timestamp" => Time.zone.local(2018, 10, 9, 11, 3, 15).to_i,
      "content" => File.open("test/fixtures/files/gravatar.png").read
    }

    assert_equal "5a6041fa4c3379560cb0cb4b0cee8f6be3adf3db7396ef8b21a557c8f37e4456", cache_content.cache_hash
    assert_equal 1539082995, cache_content.content_version
    # FIXME assert_equal expected_cache, cache_content.to_cache
    cache = cache_content.to_cache
    assert_equal expected_cache["request"], cache["request"]
    assert_equal expected_cache["response"], cache["response"]
    assert_equal expected_cache["cached_timestamp"], cache["cached_timestamp"]
    assert_equal OpenSSL::Digest::SHA256.hexdigest(expected_cache["content"]), OpenSSL::Digest::SHA256.hexdigest(cache["content"])
  end

end
