require "spec_helper"
require "webmock/rspec"
require "aws-sdk-s3"
require "nokogiri"

describe "Crawline" do
  it "has a version number" do
    expect(Crawline::VERSION).not_to be nil
  end

  describe "Downloader" do
    before do
      # Setup Downloader
      @downloader = Crawline::Downloader.new("crawline/0.1.0 (https://github.com/u6k/crawline")

      # Setup webmock
      WebMock.enable!

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/200.html").to_return(
        body: "Response 200 OK",
        status: [200, "OK"],
        headers: {
          "Content-Type" => "text/plain"
        })

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/200.html").to_return(
        body: "Response 200 OK with SSL",
        status: [200, "OK"],
        headers: {
          "Content-Type" => "text/plain"
        })

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/301.html").to_return(
        body: "Response 301 Moved Permanently",
        status: [301, "Moved Permanently"],
        headers: {
          "Location" => "http://test.crawline.u6k.me/200.html"
        })

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/301_path_only.html").to_return(
        body: "Response 301 Moved Permanently",
        status: [301, "Moved Permanently"],
        headers: {
          "Location" => "/200.html"
        })

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/404.html").to_return(
        body: "Response 404 Not Found",
        status: [404, "Not Found"])

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/500.html").to_return(
        body: "Response 500 Internal Server Error",
        status: [500, "Internal Server Error"])

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/timeout").to_timeout
    end

    after do
      WebMock.disable!
    end

    it "download successful" do
      download_result = @downloader.download_with_get("http://test.crawline.u6k.me/200.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download successful with ssl" do
      download_result = @downloader.download_with_get("https://test.crawline.u6k.me/200.html")

      expect(download_result).to eq("Response 200 OK with SSL")
    end

    it "download with redirect" do
      download_result = @downloader.download_with_get("http://test.crawline.u6k.me/301.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download with redirect path only" do
      download_result = @downloader.download_with_get("http://test.crawline.u6k.me/301_path_only.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download fail with 4xx" do
      expect {
        @downloader.download_with_get("http://test.crawline.u6k.me/404.html")
      }.to raise_error(RuntimeError, "404 Not Found")
    end

    it "download fail with 5xx" do
      expect {
        @downloader.download_with_get("http://test.crawline.u6k.me/500.html")
      }.to raise_error(RuntimeError, "500 Internal Server Error")
    end

    it "download fail with timeout" do
      expect {
        @downloader.download_with_get("http://test.crawline.u6k.me/timeout")
      }.to raise_error(Net::OpenTimeout)
    end
  end

  describe "ResourceRepository" do
    before do
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
      @repo = Crawline::ResourceRepository.new(access_key, secret_key, region, bucket, endpoint, force_path_style)
    end

    it "put data" do
      @repo.put_s3_object("put_test.txt", "put test")

      obj = @bucket.object("put_test.txt.latest")
      expect(obj.get.body.read(obj.size)).to eq("put test")
    end

    it "get data" do
      obj = @bucket.object("get_test.txt.latest")
      obj.put(body: "get test")

      data = @repo.get_s3_object("get_test.txt")

      expect(data).to eq("get test")
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

    it "remove all data" do
      @repo.remove_s3_objects
    end
  end
end

describe Crawline::Engine do
  before do
    # initialize test target object
    @downloader = Crawline::Downloader.new("test/0.0.0")

    @repo = Crawline::ResourceRepository.new(
      ENV["AWS_S3_ACCESS_KEY"],
      ENV["AWS_S3_SECRET_KEY"],
      ENV["AWS_S3_REGION"],
      ENV["AWS_S3_BUCKET"],
      ENV["AWS_S3_ENDPOINT"],
      ENV["AWS_S3_FORCE_PATH_STYLE"])

    @rules = {
      /https:\/\/blog.example.com\/index\.html/ => BlogListTestRule,
      /https:\/\/blog.example.com\/page[0-9]+\.html/ => BlogListTestRule,
      /https:\/\/blog.example.com\/pages\/.*\.html/ => BlogPageTestRule,
    }

    # remove all test data
    @repo.remove_s3_objects
  end

  describe "#initialize" do
    it "raise ArgumentError when downloader is nil" do
      expect { Crawline::Engine.new(nil, @repo, @rules) }.to raise_error ArgumentError, "downloader is nil."
    end

    it "raise TypeError when downloader is not Crawline::Downloader" do
      expect { Crawline::Engine.new("test", @repo, @rules) }.to raise_error TypeError, "downloader is not Crawline::Downloader."
    end

    it "raise ArgumentError when repo is nil." do
      expect { Crawline::Engine.new(@downloader, nil, @rules) }.to raise_error ArgumentError, "repo is nil."
    end

    it "raise TypeError when repo is not Crawline::ResourceRepository" do
      expect { Crawline::Engine.new(@downloader, "test", @rules) }.to raise_error TypeError, "repo is not Crawline::ResourceRepository."
    end

    it "raise ArgumentError when rules is nil" do
      expect { Crawline::Engine.new(@downloader, @repo, nil) }.to raise_error ArgumentError, "rules is nil."
    end

    it "raise TypeError when rules is not Hash<Regexp, Rule>" do
      @rules = {
        "https://blog.example.com/pages/scp-173.html" => BlogPageTestRule
      }

      expect { Crawline::Engine.new(@downloader, @repo, @rules) }.to raise_error TypeError, "rules is not Hash<Regexp, Rule>."
    end
  end

  describe "#select_rule" do
    before do
      @engine = Crawline::Engine.new(@downloader, @repo, @rules)
    end

    it "match rule (index)" do
      url = "https://blog.example.com/index.html"

      expect(@engine.select_rule(url)).to eq BlogListTestRule
    end

    it "match rule (page list)" do
      # page 1
      url = "https://blog.example.com/page1.html"

      expect(@engine.select_rule(url)).to eq BlogListTestRule

      # page 9
      url = "https://blog.example.com/page9.html"

      expect(@engine.select_rule(url)).to eq BlogListTestRule

      # page 10
      url = "https://blog.example.com/page10.html"

      expect(@engine.select_rule(url)).to eq BlogListTestRule
    end

    it "match rule (page)" do
      url = "https://blog.example.com/pages/scp-173.html"

      expect(@engine.select_rule(url)).to eq BlogPageTestRule
    end

    it "not match rule" do
      # index.html instead of index.htm
      url = "https://blog.example.com/index.htm"

      expect(@engine.select_rule(url)).to be nil

      # page1.html instead of page-1.html
      url = "https://blog.example.com/page-1.html"

      expect(@engine.select_rule(url)).to be nil

      # /pages/ instead of /page/
      url = "https://blog.example.com/page/scp-173.html"

      expect(@engine.select_rule(url)).to be nil
    end
  end

  describe "#get_latest_data_from_storage" do
    before do
      # put test data
      @repo.put_s3_object("ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.data", "test")

      # initialize Crawline::Engine
      @engine = Crawline::Engine.new(@downloader, @repo, @rules)
    end

    it "exist data" do
      data = @engine.get_latest_data_from_storage("https://blog.example.com/pages/scp-173.html")

      expect(data).to eq "test"
    end

    it "not exist data" do
      data = @engine.get_latest_data_from_storage("scp-173.html")

      expect(data).to be nil
    end
  end

  describe "#put_data_to_storage" do
    before do
      @engine = Crawline::Engine.new(@downloader, @repo, @rules)
    end

    it "not exist before put" do
      data = @repo.get_s3_object("ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.data")

      expect(data).to be nil
    end

    it "exist after put" do
      @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", "test")

      data = @repo.get_s3_object("ceb2236cdd616baab540663231c830b6ef2cee1ed3a98f68fa4b14e81462f7fc.data")

      expect(data).to eq "test"
    end
  end

  describe "#download_or_redownload" do
    before do
      # Setup engine
      @engine = Crawline::Engine.new(@downloader, @repo, @rules)

      # Setup webmock
      WebMock.enable!

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/index.html").
        to_return(body: File.new("spec/data/index.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/page2.html").
        to_return(body: File.new("spec/data/page2.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/page3.html").
        to_return(body: File.new("spec/data/page3.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-049.html").
        to_return(body: File.new("spec/data/pages/scp-049.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-055.html").
        to_return(body: File.new("spec/data/pages/scp-055.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-087.html").
        to_return(body: File.new("spec/data/pages/scp-087.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-093.html").
        to_return(body: File.new("spec/data/pages/scp-093.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-096.html").
        to_return(body: File.new("spec/data/pages/scp-096.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-106.html").
        to_return(body: File.new("spec/data/pages/scp-106.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-173.html").
        to_return(body: File.new("spec/data/pages/scp-173.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-231.html").
        to_return(body: File.new("spec/data/pages/scp-231.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-426.html").
        to_return(body: File.new("spec/data/pages/scp-426.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-682.html").
        to_return(body: File.new("spec/data/pages/scp-682.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-914.html").
        to_return(body: File.new("spec/data/pages/scp-914.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-2000.html").
        to_return(body: File.new("spec/data/pages/scp-2000.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-2317.html").
        to_return(body: File.new("spec/data/pages/scp-2317.html"), status: 200)

      WebMock.stub_request(:get, "https://test.crawline.u6k.me/pages/scp-2602.html").
        to_return(body: File.new("spec/data/pages/scp-2602.html"), status: 200)
    end

    after do
      WebMock.disable!
    end

    it "new download when data is nil" do
      new_data = @engine.download_or_redownload("https://test.crawline.u6k.me/index.html", BlogListTestRule, nil)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://test.crawline.u6k.me/index.html")
    end

    it "new download when redownload? is true (because 2019 year article)" do
      data = File.new("spec/data/pages/scp-2317.html").read

      new_data = @engine.download_or_redownload("https://test.crawline.u6k.me/pages/scp-2317.html", BlogPageTestRule, data)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://test.crawline.u6k.me/pages/scp-2317.html")
    end

    it "not download when redownload? is false (because 2017 year article)" do
      data = File.new("spec/data/pages/scp-2602.html").read

      new_data = @engine.download_or_redownload("https://test.crawline.u6k.me/pages/scp-2602.html", BlogPageTestRule, data)

      expect(new_data).to be nil

      expect(WebMock).not_to have_requested(:get, "https://test.crawline.u6k.me/pages/scp-2602.html")
    end
  end

  describe "#crawl" do
    it "download all pages" do
      # FIXME
    end

    it "redownload some pages" do
      # FIXME
    end

    it "download error (4xx, 5xx, timeout)" do
      # FIXME
    end
  end

  class BlogListTestRule < Crawline::BaseRule
    def initialize(url, data)
      @url = url
      @data = data
    end

    def redownload?
      true
    end
  end

  class BlogPageTestRule < Crawline::BaseRule
    def initialize(url, data)
      @url = url
      @data = data

      parse
    end

    def redownload?
      (@result["updated"].year >= 2018)
    end

    def valid?
      (not @result["updated"].nil?)
    end

    private

    def parse
      @result = {}

      doc = Nokogiri::HTML.parse(@data, nil, "UTF-8")

      doc.xpath("//div[@id='updated']").each do |div|
        @result["updated"] = Time.parse(div.text)
      end
    end
  end
end
