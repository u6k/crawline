require "spec_helper"
require "webmock/rspec"
require "aws-sdk-s3"
require "benchmark"
require "timecop"
require "zlib"

require "test_parser"

describe "Crawline" do
  it "has a version number" do
    expect(Crawline::VERSION).not_to be nil
  end

  describe "Downloader" do
    before do
      # Setup Downloader
      @downloader = Crawline::Downloader.new("crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)")

      # Setup webmock
      WebMock.enable!

      WebMock.stub_request(:get, "http://blog.example.com/200.html").to_return(
        body: "Response 200 OK",
        status: [200, "OK"],
        headers: {
          "Content-Type" => "text/plain"
        })

      WebMock.stub_request(:get, "https://blog.example.com/200.html").to_return(
        body: "Response 200 OK with SSL",
        status: [200, "OK"],
        headers: {
          "Content-Type" => "text/plain"
        })

      WebMock.stub_request(:get, "http://blog.example.com/301.html").to_return(
        body: "Response 301 Moved Permanently",
        status: [301, "Moved Permanently"],
        headers: {
          "Location" => "http://blog.example.com/200.html"
        })

      WebMock.stub_request(:get, "http://blog.example.com/301_path_only.html").to_return(
        body: "Response 301 Moved Permanently",
        status: [301, "Moved Permanently"],
        headers: {
          "Location" => "/200.html"
        })

      WebMock.stub_request(:get, "http://blog.example.com/404.html").to_return(
        body: "Response 404 Not Found",
        status: [404, "Not Found"])

      WebMock.stub_request(:get, "http://blog.example.com/500.html").to_return(
        body: "Response 500 Internal Server Error",
        status: [500, "Internal Server Error"])

      WebMock.stub_request(:get, "http://blog.example.com/timeout").to_timeout
    end

    after do
      WebMock.disable!
    end

    it "download successful" do
      download_result = Timecop.freeze(Time.utc(2019, 3, 19, 1, 8, 19)) do
        @downloader.download_with_get("http://blog.example.com/200.html")
      end

      expect(download_result).to match(
        "url" => "http://blog.example.com/200.html",
        "request_method" => "GET",
        "request_headers" => {
          "user-agent" => "crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)",
          "accept" => "*/*",
          "accept-encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "host" => "blog.example.com"
        },
        "response_headers" => {
          "content-type" => "text/plain"
        },
        "response_body" => "Response 200 OK",
        "downloaded_timestamp" => Time.utc(2019, 3, 19, 1, 8, 19))
    end

    it "download successful with ssl" do
      download_result = Timecop.freeze(Time.utc(2019, 3, 19, 2, 56, 12)) do
        @downloader.download_with_get("https://blog.example.com/200.html")
      end

      expect(download_result).to match(
        "url" => "https://blog.example.com/200.html",
        "request_method" => "GET",
        "request_headers" => {
          "user-agent" => "crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)",
          "accept" => "*/*",
          "accept-encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "host" => "blog.example.com"
        },
        "response_headers" => {
          "content-type" => "text/plain"
        },
        "response_body" => "Response 200 OK with SSL",
        "downloaded_timestamp" => Time.utc(2019, 3, 19, 2, 56, 12))
    end

    it "download with redirect" do
      download_result = Timecop.freeze(Time.utc(2019, 3, 19, 3, 8, 21)) do
        @downloader.download_with_get("http://blog.example.com/301.html")
      end

      expect(download_result).to match(
        "url" => "http://blog.example.com/301.html",
        "request_method" => "GET",
        "request_headers" => {
          "user-agent" => "crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)",
          "accept" => "*/*",
          "accept-encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "host" => "blog.example.com"
        },
        "response_headers" => {
          "content-type" => "text/plain"
        },
        "response_body" => "Response 200 OK",
        "downloaded_timestamp" => Time.utc(2019, 3, 19, 3, 8, 21))
    end

    it "download with redirect path only" do
      download_result = Timecop.freeze(Time.utc(2019, 3, 19, 18, 5, 10)) do
        @downloader.download_with_get("http://blog.example.com/301_path_only.html")
      end

      expect(download_result).to match(
        "url" => "http://blog.example.com/301_path_only.html",
        "request_method" => "GET",
        "request_headers" => {
          "user-agent" => "crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)",
          "accept" => "*/*",
          "accept-encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "host" => "blog.example.com"
        },
        "response_headers" => {
          "content-type" => "text/plain"
        },
        "response_body" => "Response 200 OK",
        "downloaded_timestamp" => Time.utc(2019, 3, 19, 18, 5, 10))
    end

    it "download fail with 4xx" do
      expect {
        @downloader.download_with_get("http://blog.example.com/404.html")
      }.to raise_error(Crawline::DownloadError, "404")
    end

    it "download fail with 5xx" do
      expect {
        @downloader.download_with_get("http://blog.example.com/500.html")
      }.to raise_error(Crawline::DownloadError, "500")
    end

    it "download fail with timeout" do
      expect {
        @downloader.download_with_get("http://blog.example.com/timeout")
      }.to raise_error(Crawline::DownloadError, "timeout")
    end
  end

  describe "ResourceRepository" do
    context "suffix is nil" do
      before do
        WebMock.disable!

        access_key = ENV["AWS_S3_ACCESS_KEY"]
        secret_key = ENV["AWS_S3_SECRET_KEY"]
        region = ENV["AWS_S3_REGION"]
        bucket = ENV["AWS_S3_BUCKET"]
        endpoint = ENV["AWS_S3_ENDPOINT"]
        force_path_style = ENV["AWS_S3_FORCE_PATH_STYLE"]
  
        # Setup S3 bucket for test
        Aws.config.update({
          region: region,
          credentials: Aws::Credentials.new(access_key, secret_key)
        })
        s3 = Aws::S3::Resource.new(endpoint: endpoint, force_path_style: force_path_style)
  
        @bucket = s3.bucket(bucket)
        @bucket.create if not @bucket.exists?
  
        # Setup ResourceRepository
        @repo = Crawline::ResourceRepository.new(access_key, secret_key, region, bucket, endpoint, force_path_style, nil)
        @repo.remove_s3_objects
      end

      it "put data" do
        @repo.put_s3_object("put_test.txt", "put test")
  
        obj = @bucket.object("put_test.txt.latest.7z")
        actual_data = @repo.decompress_data("put_test.txt", obj.get.body.read(obj.size))

        expect(actual_data).to eq("put test")
      end

      it "put struct data" do
        data = {
          "title" => "struct test data",
          "headers" => {
            "aaa" => "foo",
            "bbb" => "bar"
          },
          "timestamp" => Time.now.to_i
        }

        @repo.put_s3_object("put_struct_data.bin", data.to_json)

        obj = @bucket.object("put_struct_data.bin.latest.7z")
        actual_data = JSON.parse(@repo.decompress_data("put_struct_data.bin", obj.get.body.read(obj.size)))

        expect(actual_data).to eq data
      end
  
      it "get data" do
        obj = @bucket.object("get_test.txt.latest.7z")
        obj.put(body: @repo.compress_data("get_test.txt", "get test"))
  
        data = @repo.get_s3_object("get_test.txt")
  
        expect(data).to eq("get test")
      end

      it "get struct data" do
        data = {
          "title" => "STRUCT TEST DATA",
          "headers" => {
            "AAA" => "FOO",
            "BBB" => "BAR"
          },
          "timestamp" => Time.now.to_i
        }

        obj = @bucket.object("get_struct_data.bin.latest.7z")
        obj.put(body: @repo.compress_data("get_struct_data.bin", data.to_json))

        actual_data = JSON.parse(@repo.get_s3_object("get_struct_data.bin"))

        expect(actual_data).to eq data
      end
  
      it "get nil when object not found" do
        obj = @repo.get_s3_object("nil.txt")
  
        expect(obj).to eq(nil)
  
        @repo.put_s3_object("nil.txt", "test")
        obj = @repo.get_s3_object("nil.txt")
  
        expect(obj).to eq("test")
      end
  
      it "exists s3 object" do
        expect(@repo.exists_s3_object?("exists.txt")).to eq(false)
  
        @repo.put_s3_object("exists.txt", "test")
  
        expect(@repo.exists_s3_object?("exists.txt")).to eq(true)
      end

      it "remove s3 object" do
        @repo.put_s3_object("data_0.txt", "foo 0")
        @repo.put_s3_object("data_1.txt", "foo 1")
        @repo.put_s3_object("data_2.txt", "foo 2")

        result = []
        @repo.list_s3_objects do |obj|
          result << obj
        end

        expect(@bucket.objects.count).to eq 6
        expect(result).to contain_exactly("foo 0", "foo 1", "foo 2")

        @repo.remove_s3_object("data_1.txt")

        result = []
        @repo.list_s3_objects do |obj|
          result << obj
        end

        expect(@bucket.objects.count).to eq 4
        expect(result).to contain_exactly("foo 0", "foo 2")
      end
  
      it "remove all data" do
        @repo.put_s3_object("data_0.txt", "foo 0")
        @repo.put_s3_object("data_1.txt", "foo 1")
        @repo.put_s3_object("data_2.txt", "foo 2")

        expect(@bucket.objects.count).to eq 6

        @repo.remove_s3_objects

        expect(@bucket.objects.count).to eq 0
      end

      it "remove all data case aws page size over" do
        (0..1099).each do |i|
          @repo.put_s3_object("data_#{i}.txt", "foo #{i}")
        end

        expect(@bucket.objects.count).to eq 2200

        @repo.remove_s3_objects

        expect(@bucket.objects.count).to eq 0
      end

      it "all latest data" do
        (0..5).each do |i|
          @repo.put_s3_object("data_#{i}.txt", "foo #{i}")
        end

        result = []
        @repo.list_s3_objects do |obj|
          result << obj
        end

        expect(result).to contain_exactly("foo 0", "foo 1", "foo 2", "foo 3", "foo 4", "foo 5")
      end

      it "all latest data case aws page size over" do
        (0..1099).each do |i|
          @repo.put_s3_object("data_#{i}.txt", "bar #{i}")
        end

        result = []
        @repo.list_s3_objects do |obj|
          result << obj
        end

        expect_result = []
        (0..1099).each do |i|
          expect_result << "bar #{i}"
        end

        expect(result).to match_array(expect_result)
      end
    end

    context "set suffix" do
      before do
        WebMock.disable!

        access_key = ENV["AWS_S3_ACCESS_KEY"]
        secret_key = ENV["AWS_S3_SECRET_KEY"]
        region = ENV["AWS_S3_REGION"]
        bucket = ENV["AWS_S3_BUCKET"]
        endpoint = ENV["AWS_S3_ENDPOINT"]
        force_path_style = ENV["AWS_S3_FORCE_PATH_STYLE"]
        suffix = ENV["AWS_S3_OBJECT_NAME_SUFFIX"]
  
        # Setup S3 bucket for test
        Aws.config.update({
          region: region,
          credentials: Aws::Credentials.new(access_key, secret_key)
        })
        s3 = Aws::S3::Resource.new(endpoint: endpoint, force_path_style: force_path_style)
  
        @bucket = s3.bucket(bucket)
        @bucket.create if not @bucket.exists?
  
        # Setup ResourceRepository
        @repo = Crawline::ResourceRepository.new(access_key, secret_key, region, bucket, endpoint, force_path_style, suffix)
        @repo.remove_s3_objects
      end
  
      it "put data" do
        @repo.put_s3_object("put_test.txt", "put test")
  
        obj = @bucket.object("#{ENV["AWS_S3_OBJECT_NAME_SUFFIX"]}/put_test.txt.latest.7z")
        data = @repo.decompress_data("#{ENV["AWS_S3_OBJECT_NAME_SUFFIX"]}/put_test.txt", obj.get.body.read(obj.size))

        expect(data).to eq "put test"
      end
  
      it "get data" do
        obj = @bucket.object("#{ENV["AWS_S3_OBJECT_NAME_SUFFIX"]}/get_test.txt.latest.7z")
        obj.put(body: @repo.compress_data("#{ENV["AWS_S3_OBJECT_NAME_SUFFIX"]}/get_test.txt", "get test"))
  
        data = @repo.get_s3_object("get_test.txt")
  
        expect(data).to eq "get test"
      end
    end
  end
end

describe Crawline::Engine do
  before do
    WebMock.disable!

    # initialize test target object
    @downloader = Crawline::Downloader.new("crawline/#{Crawline::VERSION} (https://github.com/u6k/crawline)")

    @repo = Crawline::ResourceRepository.new(
      ENV["AWS_S3_ACCESS_KEY"],
      ENV["AWS_S3_SECRET_KEY"],
      ENV["AWS_S3_REGION"],
      ENV["AWS_S3_BUCKET"],
      ENV["AWS_S3_ENDPOINT"],
      ENV["AWS_S3_FORCE_PATH_STYLE"],
      nil)

    @parsers = {
      /https:\/\/blog.example.com\/index\.html/ => BlogListTestParser,
      /https:\/\/blog.example.com\/page[0-9]+\.html/ => BlogListTestParser,
      /https:\/\/blog.example.com\/pages\/.*\.html/ => BlogPageTestParser,
    }

    # remove all test data
    @repo.remove_s3_objects

    Crawline::Model::CrawlineCache.destroy_all
  end

  describe "#initialize" do
    it "raise ArgumentError when downloader is nil" do
      expect { Crawline::Engine.new(nil, @repo, @parsers, 0.001) }.to raise_error ArgumentError, "downloader is nil."
    end

    it "raise TypeError when downloader is not Crawline::Downloader" do
      expect { Crawline::Engine.new("test", @repo, @parsers, 0.001) }.to raise_error TypeError, "downloader is not Crawline::Downloader."
    end

    it "raise ArgumentError when repo is nil." do
      expect { Crawline::Engine.new(@downloader, nil, @parsers, 0.001) }.to raise_error ArgumentError, "repo is nil."
    end

    it "raise TypeError when repo is not Crawline::ResourceRepository" do
      expect { Crawline::Engine.new(@downloader, "test", @parsers, 0.001) }.to raise_error TypeError, "repo is not Crawline::ResourceRepository."
    end

    it "raise ArgumentError when parsers is nil" do
      expect { Crawline::Engine.new(@downloader, @repo, nil, 0.001) }.to raise_error ArgumentError, "parsers is nil."
    end

    it "raise TypeError when parsers is not Hash<Regexp, Parser> - 1" do
      @parsers = {
        "https://blog.example.com/pages/scp-173.html" => BlogPageTestParser
      }

      expect { Crawline::Engine.new(@downloader, @repo, @parsers, 0.001) }.to raise_error TypeError, "parsers is not Hash<Regexp, Parser>."
    end

    it "raise TypeError when parsers is not Hash<Regexp, Parser> - 2" do
      @parsers = {
        /https:\/\/blog.example.com\/index\.html/ => String
      }

      expect { Crawline::Engine.new(@downloader, @repo, @parsers, 0.001) }.to raise_error TypeError, "parsers is not Hash<Regexp, Parser>."
    end
  end

  describe "#find_parser" do
    before do
      @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)
    end

    it "found parser (case index)" do
      url = "https://blog.example.com/index.html"

      expect(@engine.find_parser(url)).to eq BlogListTestParser
    end

    it "found parser (case page list)" do
      # page 1
      url = "https://blog.example.com/page1.html"

      expect(@engine.find_parser(url)).to eq BlogListTestParser

      # page 9
      url = "https://blog.example.com/page9.html"

      expect(@engine.find_parser(url)).to eq BlogListTestParser

      # page 10
      url = "https://blog.example.com/page10.html"

      expect(@engine.find_parser(url)).to eq BlogListTestParser
    end

    it "find parser (case page)" do
      url = "https://blog.example.com/pages/scp-173.html"

      expect(@engine.find_parser(url)).to eq BlogPageTestParser
    end

    it "not found parser" do
      # index.html instead of index.htm
      url = "https://blog.example.com/index.htm"

      expect { @engine.find_parser(url) }.to raise_error Crawline::ParserNotFoundError, "https://blog.example.com/index.htm"

      # page1.html instead of page-1.html
      url = "https://blog.example.com/page-1.html"

      expect { @engine.find_parser(url) }.to raise_error Crawline::ParserNotFoundError, "https://blog.example.com/page-1.html"

      # /pages/ instead of /page/
      url = "https://blog.example.com/page/scp-173.html"

      expect { @engine.find_parser(url) }.to raise_error Crawline::ParserNotFoundError, "https://blog.example.com/page/scp-173.html"
    end
  end

  describe "#get_latest_data_from_storage" do
    context "text data" do
      before do
        # initialize Crawline::Engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        # put test data
        @data = {
          "url" => "https://blog.example.com/pages/scp-173.html",
          "request_method" => "GET",
          "request_headers" => {
            "accept" => "*/*",
            "user-agent" => "crawline/0.0.0"
          },
          "response_headers" => {
            "content-type" => "text/plain",
            "content-length" => "123"
          },
          "response_body" => File.open("spec/data/pages/scp-173.html").read,
          "downloaded_timestamp" => Time.utc(2019, 3, 22, 10, 9, 23, 0)
        }

        @repo.put_s3_object("ce/ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.json", @engine.data_to_json(@data))
      end

      it "exist data" do
        stored_data = @engine.get_latest_data_from_storage("https://blog.example.com/pages/scp-173.html")

        expect(stored_data).to eq @data
      end

      it "not exist data" do
        stored_data = @engine.get_latest_data_from_storage("scp-173.html")

        expect(stored_data).to be nil
      end
    end

    context "binary data" do
      before do
        # initialize Crawline::Engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        # put test data
        @data = {
          "url" => "https://blog.example.com/download/data.zip",
          "request_method" => "GET",
          "request_headers" => {
            "accept" => "*/*",
            "user-agent" => "crawline/0.0.0"
          },
          "response_headers" => {
            "content-type" => "application/zip",
            "content-length" => "234"
          },
          "response_body" => File.open("spec/data/data.zip").read,
          "downloaded_timestamp" => Time.utc(2019, 4, 25, 16, 28, 4, 0)
        }

        @repo.put_s3_object("c5/c53c88fa6e5f77c5ec6d72e04b8aeaf041bf5b582a13b4aef03de893fcfa92b6.json", @engine.data_to_json(@data))
      end

      it "exist data" do
        stored_data = @engine.get_latest_data_from_storage("https://blog.example.com/download/data.zip")

        expect(stored_data).to eq @data
      end

      it "not exist data" do
        stored_data = @engine.get_latest_data_from_storage("data.zip")

        expect(stored_data).to be nil
      end
    end
  end

  describe "#put_data_to_storage" do
    context "text data" do
      before do
        # setup test data
        @data = {
          "url" => "https://blog.example.com/pages/scp-173.html",
          "request_method" => "GET",
          "request_headers" => {
            "accept" => "*/*",
            "user-agent" => "crawline/0.0.0"
          },
          "response_headers" => {
            "content-type" => "text/plain",
            "content-length" => "123"
          },
          "response_body" => File.open("spec/data/pages/scp-173.html").read,
          "downloaded_timestamp" => Time.utc(2019, 3, 22, 10, 9, 23, 0)
        }

        @data_index = {
          "url" => "https://blog.example.com/index.html",
          "request_method" => "GET",
          "request_headers" => {
            "accept" => "*/*",
            "user-agent" => "crawline/0.0.0"
          },
          "response_headers" => {
            "content-type" => "text/plain",
            "content-length" => "123"
          },
          "response_body" => File.open("spec/data/index.html").read,
          "downloaded_timestamp" => Time.utc(2019, 5, 9, 14, 49, 13)
        }

        # setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)
      end

      it "not exist before put" do
        stored_data = @repo.get_s3_object("ce/ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.json")

        expect(stored_data).to be nil
      end

      it "exist after put" do
        url = "https://blog.example.com/pages/scp-173.html"

        parser = BlogPageTestParser.new(url, @data)

        @engine.put_data_to_storage(url, @data, parser.related_links)

        stored_data = @engine.json_to_data(@repo.get_s3_object("ce/ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.json"))

        expect(stored_data).to eq @data

        expect(Crawline::Model::CrawlineCache.all).to match_array([
          have_attributes(url: "https://blog.example.com/pages/scp-173.html", request_method: "GET", downloaded_timestamp: Time.utc(2019, 3, 22, 10, 9, 23))
        ])

        expect(Crawline::Model::CrawlineHeader.all).to match_array([
          have_attributes(message_type: "request",  header_name: "accept",         header_value: "*/*"),
          have_attributes(message_type: "request",  header_name: "user-agent",     header_value: "crawline/0.0.0"),
          have_attributes(message_type: "response", header_name: "content-type",   header_value: "text/plain"),
          have_attributes(message_type: "response", header_name: "content-length", header_value: "123"),
        ])

        expect(Crawline::Model::CrawlineRelatedLink.all).to be_empty
      end

      it "exist after put" do
        url = "https://blog.example.com/index.html"

        parser = BlogListTestParser.new(url, @data_index)

        @engine.put_data_to_storage(url, @data_index, parser.related_links)

        stored_data = @engine.json_to_data(@repo.get_s3_object("8b/8b2b65d6eed92b6408276cd807a8dceb716abc09fd0cbbc50f8446207b250a1f.json"))

        expect(stored_data).to eq @data_index

        expect(Crawline::Model::CrawlineCache.all).to match_array([
          have_attributes(url: "https://blog.example.com/index.html", request_method: "GET", downloaded_timestamp: Time.utc(2019, 5, 9, 14, 49, 13))
        ])

        expect(Crawline::Model::CrawlineHeader.all).to match_array([
          have_attributes(message_type: "request",  header_name: "accept",         header_value: "*/*"),
          have_attributes(message_type: "request",  header_name: "user-agent",     header_value: "crawline/0.0.0"),
          have_attributes(message_type: "response", header_name: "content-type",   header_value: "text/plain"),
          have_attributes(message_type: "response", header_name: "content-length", header_value: "123"),
        ])

        expect(Crawline::Model::CrawlineRelatedLink.all).to match_array([
          have_attributes(url: "https://blog.example.com/pages/scp-173.html"),
          have_attributes(url: "https://blog.example.com/pages/scp-087.html"),
          have_attributes(url: "https://blog.example.com/pages/scp-055.html"),
          have_attributes(url: "https://blog.example.com/pages/scp-682.html"),
          have_attributes(url: "https://blog.example.com/pages/scp-093.html"),
          have_attributes(url: "https://blog.example.com/page2.html"),
        ])
      end

      it "is same data, put and get" do
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", @data, [])

        stored_data = @engine.get_latest_data_from_storage("https://blog.example.com/pages/scp-173.html")

        expect(stored_data).to eq @data
      end
    end

    context "binary data" do
      before do
        # setup test data
        @data = {
          "url" => "https://blog.example.com/download/data.zip",
          "request_method" => "GET",
          "request_headers" => {
            "accept" => "*/*",
            "user-agent" => "crawline/0.0.0"
          },
          "response_headers" => {
            "content-type" => "application/zip",
            "content-length" => "234"
          },
          "response_body" => File.open("spec/data/data.zip").read,
          "downloaded_timestamp" => Time.utc(2019, 4, 25, 16, 35, 14, 0)
        }

        # setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)
      end

      it "not exist before put" do
        stored_data = @repo.get_s3_object("c5/c53c88fa6e5f77c5ec6d72e04b8aeaf041bf5b582a13b4aef03de893fcfa92b6.json")

        expect(stored_data).to be nil
      end

      it "exist after put" do
        @engine.put_data_to_storage("https://blog.example.com/download/data.zip", @data, [])

        stored_data = @engine.json_to_data(@repo.get_s3_object("c5/c53c88fa6e5f77c5ec6d72e04b8aeaf041bf5b582a13b4aef03de893fcfa92b6.json"))

        expect(stored_data).to eq @data
      end

      it "is same data, put and get" do
        @engine.put_data_to_storage("https://blog.example.com/download/data.zip", @data, [])

        stored_data = @engine.get_latest_data_from_storage("https://blog.example.com/download/data.zip")

        expect(stored_data).to eq @data
      end
    end
  end

  describe "#download_or_redownload" do
    before do
      # Setup engine
      @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

      # Setup webmock
      WebMock.enable!

      WebMock.stub_request(:get, "https://blog.example.com/index.html").
        to_return(body: File.new("spec/data/index.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/page2.html").
        to_return(body: File.new("spec/data/page2.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/page3.html").
        to_return(body: File.new("spec/data/page3.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-049.html").
        to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-055.html").
        to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-087.html").
        to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-093.html").
        to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-096.html").
        to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-106.html").
        to_return(body: File.new("spec/data/pages/scp-106.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-173.html").
        to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-231.html").
        to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-426.html").
        to_return(body: File.new("spec/data/pages/scp-426.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-682.html").
        to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-914.html").
        to_return(body: File.new("spec/data/pages/scp-914.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2000.html").
        to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2317.html").
        to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2602.html").
        to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)
    end

    after do
      WebMock.disable!
    end

    it "new download when data is nil" do
      new_data = @engine.download_or_redownload("https://blog.example.com/index.html", BlogListTestParser, nil)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://blog.example.com/index.html")
    end

    it "new download when redownload? is true (because 2019 year article)" do
      data = {
        "url" => "https://blog.example.com/pages/scp-2317.html",
        "request_method" => "GET",
        "request_headers" => {},
        "response_headers" => {},
        "response_body" => File.new("spec/data/pages/scp-2317.html").read,
        "downloaded_timestamp" => Time.now.utc
      }

      new_data = @engine.download_or_redownload("https://blog.example.com/pages/scp-2317.html", BlogPageTestParser, data)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2317.html")
    end

    it "same data when redownload? is false (because 2017 year article)" do
      data = {
        "url" => "https://blog.example.com/pages/scp-2602.html",
        "request_method" => "GET",
        "request_headers" => {},
        "response_headers" => {},
        "response_body" => File.new("spec/data/pages/scp-2602.html").read,
        "downloaded_timestamp" => Time.now.utc
      }

      new_data = @engine.download_or_redownload("https://blog.example.com/pages/scp-2602.html", BlogPageTestParser, data)

      expect(new_data).to be nil

      expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2602.html")
    end
  end

  describe "#crawl" do
    context "first download" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        # Setup webmock
        WebMock.enable!

        WebMock.stub_request(:get, "https://blog.example.com/index.html").
          to_return(body: File.new("spec/data/index.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page2.html").
          to_return(body: File.new("spec/data/page2.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page3.html").
          to_return(body: File.new("spec/data/page3.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-049.html").
          to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-055.html").
          to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-087.html").
          to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-093.html").
          to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-096.html").
          to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-106.html").
          to_return(body: File.new("spec/data/pages/scp-106.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-173.html").
          to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-231.html").
          to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-426.html").
          to_return(body: File.new("spec/data/pages/scp-426.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-682.html").
          to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-914.html").
          to_return(body: File.new("spec/data/pages/scp-914.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2000.html").
          to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2317.html").
          to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2602.html").
          to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)
      end

      after do
        WebMock.disable!
      end

      it "download all pages" do
        result = @engine.crawl("https://blog.example.com/index.html")

        expect(result["success_url_list"]).to contain_exactly(
          "https://blog.example.com/index.html",
          "https://blog.example.com/page2.html",
          "https://blog.example.com/page3.html",
          "https://blog.example.com/pages/scp-049.html",
          "https://blog.example.com/pages/scp-055.html",
          "https://blog.example.com/pages/scp-087.html",
          "https://blog.example.com/pages/scp-093.html",
          "https://blog.example.com/pages/scp-096.html",
          "https://blog.example.com/pages/scp-106.html",
          "https://blog.example.com/pages/scp-173.html",
          "https://blog.example.com/pages/scp-231.html",
          "https://blog.example.com/pages/scp-426.html",
          "https://blog.example.com/pages/scp-682.html",
          "https://blog.example.com/pages/scp-914.html",
          "https://blog.example.com/pages/scp-2000.html",
          "https://blog.example.com/pages/scp-2317.html",
          "https://blog.example.com/pages/scp-2602.html")

        expect(result["fail_url_list"]).to contain_exactly()

        expect(result["context"]).to match(
          "scp-049" => {
            "title" => "SCP-049 - ペスト医師",
            "item_number" => "SCP-049",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-29 12:23")
          },
          "scp-055" => {
            "title" => "SCP-055 - [正体不明]",
            "item_number" => "SCP-055",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-10-14 12:49")
          },
          "scp-087" => {
            "title" => "SCP-087 - 吹き抜けた階段",
            "item_number" => "SCP-087",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-11-04 14:56")
          },
          "scp-093" => {
            "title" => "SCP-093 - 紅海の円盤",
            "item_number" => "SCP-093",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-05-12 01:41")
          },
          "scp-096" => {
            "title" => "SCP-096 - \"シャイガイ\"",
            "item_number" => "SCP-096",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-17 01:24")
          },
          "scp-106" => {
            "title" => "SCP-106 - オールドマン",
            "item_number" => "SCP-106",
            "object_class" => "Keter",
            "updated" => Time.parse("2019-01-18 05:39")
          },
          "scp-173" => {
            "title" => "SCP-173 - 彫刻 - オリジナル",
            "item_number" => "SCP-173",
            "object_class" => "Euclid",
            "updated" => Time.parse("2019-01-06 18:14")
          },
          "scp-231" => {
            "title" => "SCP-231 - 特別職員要件",
            "item_number" => "SCP-231",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-12-29 12:29")
          },
          "scp-426" => {
            "title" => "SCP-426 - 私はトースター",
            "item_number" => "SCP-426",
            "object_class" => "Euclid",
            "updated" => Time.parse("2017-06-04 21:53")
          },
          "scp-682" => {
            "title" => "SCP-682 - 不死身の爬虫類",
            "item_number" => "SCP-682",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-11-11 20:07")
          },
          "scp-914" => {
            "title" => "SCP-914 - ぜんまい仕掛け",
            "item_number" => "SCP-914",
            "object_class" => "Safe",
            "updated" => Time.parse("2017-12-01 18:01")
          },
          "scp-2000" => {
            "title" => "SCP-2000 - 機械仕掛けの神",
            "item_number" => "SCP-2000",
            "object_class" => "Thaumiel",
            "updated" => Time.parse("2018-09-25 16:39")
          },
          "scp-2317" => {
            "title" => "SCP-2317 - 異世界への扉",
            "item_number" => "SCP-2317",
            "updated" => Time.parse("2019-01-18 23:53")
          },
          "scp-2602" => {
            "title" => "かつて図書館だったSCP-2602",
            "item_number" => "SCP-2602",
            "object_class" => "Former",
            "updated" => Time.parse("2017-05-16 15:27")
          })

        expect(WebMock).to have_requested(:get, "https://blog.example.com/index.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page2.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page3.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-049.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-055.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-087.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-093.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-096.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-106.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-173.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-231.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-426.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-682.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-914.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2000.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2317.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2602.html")
      end
    end

    context "all downloaded" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        # Setup webmock
        WebMock.enable!

        WebMock.stub_request(:get, "https://blog.example.com/index.html").
          to_return(body: File.new("spec/data/index.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page2.html").
          to_return(body: File.new("spec/data/page2.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page3.html").
          to_return(body: File.new("spec/data/page3.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-049.html").
          to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-055.html").
          to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-087.html").
          to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-093.html").
          to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-096.html").
          to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-106.html").
          to_return(body: File.new("spec/data/pages/scp-106.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-173.html").
          to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-231.html").
          to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-426.html").
          to_return(body: File.new("spec/data/pages/scp-426.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-682.html").
          to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-914.html").
          to_return(body: File.new("spec/data/pages/scp-914.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2000.html").
          to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2317.html").
          to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2602.html").
          to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)

        # Setup downloaded data
        @engine.put_data_to_storage("https://blog.example.com/index.html", {
          "url" => "https://blog.example.com/index.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/index.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/page2.html", {
          "url" => "https://blog.example.com/page2.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/page2.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/page3.html", {
          "url" => "https://blog.example.com/page3.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/page3.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-049.html", {
          "url" => "https://blog.example.com/pages/scp-049.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-049.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-055.html", {
          "url" => "https://blog.example.com/pages/scp-055.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-055.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-087.html", {
          "url" => "https://blog.example.com/pages/scp-087.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-087.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-093.html", {
          "url" => "https://blog.example.com/pages/scp-093.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-093.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-096.html", {
          "url" => "https://blog.example.com/pages/scp-096.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-096.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-106.html", {
          "url" => "https://blog.example.com/pages/scp-106.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-106.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", {
          "url" => "https://blog.example.com/pages/scp-173.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-173.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-231.html", {
          "url" => "https://blog.example.com/pages/scp-231.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-231.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-426.html", {
          "url" => "https://blog.example.com/pages/scp-426.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-426.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-682.html", {
          "url" => "https://blog.example.com/pages/scp-682.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-682.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-914.html", {
          "url" => "https://blog.example.com/pages/scp-914.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-914.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2000.html", {
          "url" => "https://blog.example.com/pages/scp-2000.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2000.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2317.html", {
          "url" => "https://blog.example.com/pages/scp-2317.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2317.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2602.html", {
          "url" => "https://blog.example.com/pages/scp-2602.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2602.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
      end

      after do
        WebMock.disable!
      end

      it "redownload some pages" do
        result = @engine.crawl("https://blog.example.com/index.html")

        expect(result["success_url_list"]).to contain_exactly(
          "https://blog.example.com/index.html",
          "https://blog.example.com/page2.html",
          "https://blog.example.com/page3.html",
          "https://blog.example.com/pages/scp-049.html",
          "https://blog.example.com/pages/scp-055.html",
          "https://blog.example.com/pages/scp-087.html",
          "https://blog.example.com/pages/scp-093.html",
          "https://blog.example.com/pages/scp-096.html",
          "https://blog.example.com/pages/scp-106.html",
          "https://blog.example.com/pages/scp-173.html",
          "https://blog.example.com/pages/scp-231.html",
          "https://blog.example.com/pages/scp-426.html",
          "https://blog.example.com/pages/scp-682.html",
          "https://blog.example.com/pages/scp-914.html",
          "https://blog.example.com/pages/scp-2000.html",
          "https://blog.example.com/pages/scp-2317.html",
          "https://blog.example.com/pages/scp-2602.html")

        expect(result["fail_url_list"]).to contain_exactly()

        expect(result["context"]).to match(
          "scp-049" => {
            "title" => "SCP-049 - ペスト医師",
            "item_number" => "SCP-049",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-29 12:23")
          },
          "scp-055" => {
            "title" => "SCP-055 - [正体不明]",
            "item_number" => "SCP-055",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-10-14 12:49")
          },
          "scp-087" => {
            "title" => "SCP-087 - 吹き抜けた階段",
            "item_number" => "SCP-087",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-11-04 14:56")
          },
          "scp-093" => {
            "title" => "SCP-093 - 紅海の円盤",
            "item_number" => "SCP-093",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-05-12 01:41")
          },
          "scp-096" => {
            "title" => "SCP-096 - \"シャイガイ\"",
            "item_number" => "SCP-096",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-17 01:24")
          },
          "scp-106" => {
            "title" => "SCP-106 - オールドマン",
            "item_number" => "SCP-106",
            "object_class" => "Keter",
            "updated" => Time.parse("2019-01-18 05:39")
          },
          "scp-173" => {
            "title" => "SCP-173 - 彫刻 - オリジナル",
            "item_number" => "SCP-173",
            "object_class" => "Euclid",
            "updated" => Time.parse("2019-01-06 18:14")
          },
          "scp-231" => {
            "title" => "SCP-231 - 特別職員要件",
            "item_number" => "SCP-231",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-12-29 12:29")
          },
          "scp-682" => {
            "title" => "SCP-682 - 不死身の爬虫類",
            "item_number" => "SCP-682",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-11-11 20:07")
          },
          "scp-2000" => {
            "title" => "SCP-2000 - 機械仕掛けの神",
            "item_number" => "SCP-2000",
            "object_class" => "Thaumiel",
            "updated" => Time.parse("2018-09-25 16:39")
          },
          "scp-2317" => {
            "title" => "SCP-2317 - 異世界への扉",
            "item_number" => "SCP-2317",
            "updated" => Time.parse("2019-01-18 23:53")
          })

        expect(WebMock).to have_requested(:get, "https://blog.example.com/index.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page2.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page3.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-049.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-055.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-087.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-093.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-096.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-106.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-173.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-231.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-682.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2000.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2317.html")

        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-426.html")
        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-914.html")
        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2602.html")
      end
    end

    context "downloading of some pages results with error" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        # Setup webmock
        WebMock.enable!

        WebMock.stub_request(:get, "https://blog.example.com/index.html").
          to_return(body: File.new("spec/data/index.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page2.html").
          to_return(body: File.new("spec/data/page2.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/page3.html").
          to_return(status: 404)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-049.html").
          to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-055.html").
          to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-087.html").
          to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-093.html").
          to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-096.html").
          to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-106.html").
          to_return(status: 404)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-173.html").
          to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-231.html").
          to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-426.html").
          to_return(status: 500)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-682.html").
          to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-914.html").
          to_timeout

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2000.html").
          to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2317.html").
          to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

        WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2602.html").
          to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)
      end

      after do
        WebMock.disable!
      end

      it "download error (4xx, 5xx, timeout)" do
        result = @engine.crawl("https://blog.example.com/index.html")

        expect(result["success_url_list"]).to contain_exactly(
          "https://blog.example.com/index.html",
          "https://blog.example.com/page2.html",
          "https://blog.example.com/pages/scp-173.html",
          "https://blog.example.com/pages/scp-087.html",
          "https://blog.example.com/pages/scp-055.html",
          "https://blog.example.com/pages/scp-682.html",
          "https://blog.example.com/pages/scp-093.html",
          "https://blog.example.com/pages/scp-049.html",
          "https://blog.example.com/pages/scp-096.html")

        expect(result["fail_url_list"]).to contain_exactly(
          "https://blog.example.com/page3.html",
          "https://blog.example.com/pages/scp-914.html",
          "https://blog.example.com/pages/scp-106.html",
          "https://blog.example.com/pages/scp-426.html")

        expect(WebMock).to have_requested(:get, "https://blog.example.com/index.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page2.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/page3.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-049.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-055.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-087.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-093.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-096.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-106.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-173.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-426.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-682.html")
        expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-914.html")

        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-231.html")
        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2000.html")
        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2317.html")
        expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2602.html")
      end
    end
  end

  describe "#parse" do
    context "cache complete" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)
  
        # Setup downloaded data
        @engine.put_data_to_storage("https://blog.example.com/index.html", {
          "url" => "https://blog.example.com/index.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/index.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/page2.html", {
          "url" => "https://blog.example.com/page2.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/page2.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/page3.html", {
          "url" => "https://blog.example.com/page3.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/page3.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-049.html", {
          "url" => "https://blog.example.com/pages/scp-049.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-049.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-055.html", {
          "url" => "https://blog.example.com/pages/scp-055.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-055.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-087.html", {
          "url" => "https://blog.example.com/pages/scp-087.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-087.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-093.html", {
          "url" => "https://blog.example.com/pages/scp-093.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-093.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-096.html", {
          "url" => "https://blog.example.com/pages/scp-096.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-096.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-106.html", {
          "url" => "https://blog.example.com/pages/scp-106.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-106.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", {
          "url" => "https://blog.example.com/pages/scp-173.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-173.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-231.html", {
          "url" => "https://blog.example.com/pages/scp-231.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-231.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-426.html", {
          "url" => "https://blog.example.com/pages/scp-426.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-426.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-682.html", {
          "url" => "https://blog.example.com/pages/scp-682.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-682.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-914.html", {
          "url" => "https://blog.example.com/pages/scp-914.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-914.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2000.html", {
          "url" => "https://blog.example.com/pages/scp-2000.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2000.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2317.html", {
          "url" => "https://blog.example.com/pages/scp-2317.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2317.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2602.html", {
          "url" => "https://blog.example.com/pages/scp-2602.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-2602.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
      end
  
      it "parse all pages" do
        data = @engine.parse("https://blog.example.com/index.html")
  
        expect(data).to match(
          "scp-049" => {
            "title" => "SCP-049 - ペスト医師",
            "item_number" => "SCP-049",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-29 12:23")
          },
          "scp-055" => {
            "title" => "SCP-055 - [正体不明]",
            "item_number" => "SCP-055",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-10-14 12:49")
          },
          "scp-087" => {
            "title" => "SCP-087 - 吹き抜けた階段",
            "item_number" => "SCP-087",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-11-04 14:56")
          },
          "scp-093" => {
            "title" => "SCP-093 - 紅海の円盤",
            "item_number" => "SCP-093",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-05-12 01:41")
          },
          "scp-096" => {
            "title" => "SCP-096 - \"シャイガイ\"",
            "item_number" => "SCP-096",
            "object_class" => "Euclid",
            "updated" => Time.parse("2018-12-17 01:24")
          },
          "scp-106" => {
            "title" => "SCP-106 - オールドマン",
            "item_number" => "SCP-106",
            "object_class" => "Keter",
            "updated" => Time.parse("2019-01-18 05:39")
          },
          "scp-173" => {
            "title" => "SCP-173 - 彫刻 - オリジナル",
            "item_number" => "SCP-173",
            "object_class" => "Euclid",
            "updated" => Time.parse("2019-01-06 18:14")
          },
          "scp-231" => {
            "title" => "SCP-231 - 特別職員要件",
            "item_number" => "SCP-231",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-12-29 12:29")
          },
          "scp-426" => {
            "title" => "SCP-426 - 私はトースター",
            "item_number" => "SCP-426",
            "object_class" => "Euclid",
            "updated" => Time.parse("2017-06-04 21:53")
          },
          "scp-682" => {
            "title" => "SCP-682 - 不死身の爬虫類",
            "item_number" => "SCP-682",
            "object_class" => "Keter",
            "updated" => Time.parse("2018-11-11 20:07")
          },
          "scp-914" => {
            "title" => "SCP-914 - ぜんまい仕掛け",
            "item_number" => "SCP-914",
            "object_class" => "Safe",
            "updated" => Time.parse("2017-12-01 18:01")
          },
          "scp-2000" => {
            "title" => "SCP-2000 - 機械仕掛けの神",
            "item_number" => "SCP-2000",
            "object_class" => "Thaumiel",
            "updated" => Time.parse("2018-09-25 16:39")
          },
          "scp-2317" => {
            "title" => "SCP-2317 - 異世界への扉",
            "item_number" => "SCP-2317",
            "updated" => Time.parse("2019-01-18 23:53")
          },
          "scp-2602" => {
            "title" => "かつて図書館だったSCP-2602",
            "item_number" => "SCP-2602",
            "object_class" => "Former",
            "updated" => Time.parse("2017-05-16 15:27")
          })
      end
  
      it "parse a page" do
        data = @engine.parse("https://blog.example.com/pages/scp-173.html")
  
        expect(data).to match(
          "scp-173" => {
            "title" => "SCP-173 - 彫刻 - オリジナル",
            "item_number" => "SCP-173",
            "object_class" => "Euclid",
            "updated" => Time.parse("2019-01-06 18:14")
          })
      end
    end

    context "cache incomplete" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

        @engine.put_data_to_storage("https://blog.example.com/index.html", {
          "url" => "https://blog.example.com/index.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/index.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", {
          "url" => "https://blog.example.com/pages/scp-173.html",
          "request_method" => "GET",
          "request_headers" => {},
          "response_headers" => {},
          "response_body" => File.new("spec/data/pages/scp-173.html").read,
          "downloaded_timestamp" => Time.now.utc}, [])
      end

      it "parse all pages" do
        data = @engine.parse("https://blog.example.com/index.html")

        expect(data).to match(
          "scp-173" => {
            "title" => "SCP-173 - 彫刻 - オリジナル",
            "item_number" => "SCP-173",
            "object_class" => "Euclid",
            "updated" => Time.parse("2019-01-06 18:14")
          })
      end
    end
  end

  describe "crawl interval" do
    before do
      # Setup webmock
      WebMock.enable!

      WebMock.stub_request(:get, "https://blog.example.com/index.html").
        to_return(body: File.new("spec/data/index.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/page2.html").
        to_return(body: File.new("spec/data/page2.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/page3.html").
        to_return(body: File.new("spec/data/page3.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-049.html").
        to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-055.html").
        to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-087.html").
        to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-093.html").
        to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-096.html").
        to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-106.html").
        to_return(body: File.new("spec/data/pages/scp-106.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-173.html").
        to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-231.html").
        to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-426.html").
        to_return(body: File.new("spec/data/pages/scp-426.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-682.html").
        to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-914.html").
        to_return(body: File.new("spec/data/pages/scp-914.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2000.html").
        to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2317.html").
        to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

      WebMock.stub_request(:get, "https://blog.example.com/pages/scp-2602.html").
        to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)
    end

    after do
      WebMock.disable!
    end

    it "crawl at 0.001 sec interval" do
      engine = Crawline::Engine.new(@downloader, @repo, @parsers, 0.001)

      time = Benchmark.realtime do
        engine.crawl("https://blog.example.com/index.html")
      end

      expect(time).to be_within(0.5).of(0.5)
    end

    it "carwl at 1 sec interval" do
      engine = Crawline::Engine.new(@downloader, @repo, @parsers)

      time = Benchmark.realtime do
        engine.crawl("https://blog.example.com/index.html")
      end

      expect(time).to be_within(0.5).of(17.5)
    end
  end
end

