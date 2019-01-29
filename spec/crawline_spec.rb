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
      download_result = @downloader.download_with_get("http://blog.example.com/200.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download successful with ssl" do
      download_result = @downloader.download_with_get("https://blog.example.com/200.html")

      expect(download_result).to eq("Response 200 OK with SSL")
    end

    it "download with redirect" do
      download_result = @downloader.download_with_get("http://blog.example.com/301.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download with redirect path only" do
      download_result = @downloader.download_with_get("http://blog.example.com/301_path_only.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download fail with 4xx" do
      expect {
        @downloader.download_with_get("http://blog.example.com/404.html")
      }.to raise_error(RuntimeError, "404 Not Found")
    end

    it "download fail with 5xx" do
      expect {
        @downloader.download_with_get("http://blog.example.com/500.html")
      }.to raise_error(RuntimeError, "500 Internal Server Error")
    end

    it "download fail with timeout" do
      expect {
        @downloader.download_with_get("http://blog.example.com/timeout")
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
      new_data = @engine.download_or_redownload("https://blog.example.com/index.html", BlogListTestRule, nil)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://blog.example.com/index.html")
    end

    it "new download when redownload? is true (because 2019 year article)" do
      data = File.new("spec/data/pages/scp-2317.html").read

      new_data = @engine.download_or_redownload("https://blog.example.com/pages/scp-2317.html", BlogPageTestRule, data)

      expect(new_data).not_to be nil

      expect(WebMock).to have_requested(:get, "https://blog.example.com/pages/scp-2317.html")
    end

    it "not download when redownload? is false (because 2017 year article)" do
      data = File.new("spec/data/pages/scp-2602.html").read

      new_data = @engine.download_or_redownload("https://blog.example.com/pages/scp-2602.html", BlogPageTestRule, data)

      expect(new_data).to be nil

      expect(WebMock).not_to have_requested(:get, "https://blog.example.com/pages/scp-2602.html")
    end
  end

  describe "#crawl" do
    context "first download" do
      before do
        # Setup engine
        @engine = Crawline::Engine.new(@downloader, @repo, @rules)

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
        @engine = Crawline::Engine.new(@downloader, @repo, @rules)

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
        @engine.put_data_to_storage("https://blog.example.com/index.html", File.new("spec/data/index.html").read)
        @engine.put_data_to_storage("https://blog.example.com/page2.html", File.new("spec/data/page2.html").read)
        @engine.put_data_to_storage("https://blog.example.com/page3.html", File.new("spec/data/page3.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-049.html", File.new("spec/data/pages/scp-049.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-055.html", File.new("spec/data/pages/scp-055.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-087.html", File.new("spec/data/pages/scp-087.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-093.html", File.new("spec/data/pages/scp-093.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-096.html", File.new("spec/data/pages/scp-096.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-106.html", File.new("spec/data/pages/scp-106.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", File.new("spec/data/pages/scp-173.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-231.html", File.new("spec/data/pages/scp-231.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-426.html", File.new("spec/data/pages/scp-426.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-682.html", File.new("spec/data/pages/scp-682.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-914.html", File.new("spec/data/pages/scp-914.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2000.html", File.new("spec/data/pages/scp-2000.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2317.html", File.new("spec/data/pages/scp-2317.html").read)
        @engine.put_data_to_storage("https://blog.example.com/pages/scp-2602.html", File.new("spec/data/pages/scp-2602.html").read)
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
          "https://blog.example.com/pages/scp-682.html",
          "https://blog.example.com/pages/scp-2000.html",
          "https://blog.example.com/pages/scp-2317.html")

        expect(result["fail_url_list"]).to contain_exactly()

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
        @engine = Crawline::Engine.new(@downloader, @repo, @rules)

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

# FIXME: impl test
#  describe "#parse" do
#    before do
#      # Setup engine
#      @engine = Crawline::Engine.new(@downloader, @repo, @rules)
#
#      # Setup downloaded data
#      @engine.put_data_to_storage("https://blog.example.com/index.html", File.new("spec/data/index.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/page2.html", File.new("spec/data/page2.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/page3.html", File.new("spec/data/page3.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-049.html", File.new("spec/data/pages/scp-049.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-055.html", File.new("spec/data/pages/scp-055.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-087.html", File.new("spec/data/pages/scp-087.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-093.html", File.new("spec/data/pages/scp-093.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-096.html", File.new("spec/data/pages/scp-096.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-106.html", File.new("spec/data/pages/scp-106.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-173.html", File.new("spec/data/pages/scp-173.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-231.html", File.new("spec/data/pages/scp-231.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-426.html", File.new("spec/data/pages/scp-426.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-682.html", File.new("spec/data/pages/scp-682.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-914.html", File.new("spec/data/pages/scp-914.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-2000.html", File.new("spec/data/pages/scp-2000.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-2317.html", File.new("spec/data/pages/scp-2317.html").read)
#      @engine.put_data_to_storage("https://blog.example.com/pages/scp-2602.html", File.new("spec/data/pages/scp-2602.html").read)
#    end
#
#    it "parse all pages" do
#      data = @engine.parse("https://blog.example.com/index.html")
#
#      expect(data).to match(
#        "scp-049" => {
#          "title" => "SCP-049 - ペスト医師",
#          "item_number" => "SCP-049",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2018-12-29 12:23")
#        },
#        "scp-055" => {
#          "title" => "SCP-055 - [正体不明]",
#          "item_number" => "SCP-055",
#          "object_class" => "Keter",
#          "updated" => Time.parse("2018-10-14 12:49")
#        },
#        "scp-087" => {
#          "title" => "SCP-087 - 吹き抜けた階段",
#          "item_number" => "SCP-087",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2018-11-04 14:56")
#        },
#        "scp-093" => {
#          "title" => "SCP-093 - 紅海の円盤",
#          "item_number" => "SCP-093",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2018-05-12 01:41")
#        },
#        "scp-096" => {
#          "title" => "SCP-096 - \"シャイガイ\"",
#          "item_number" => "SCP-096",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2018-12-17 01:24")
#        },
#        "scp-106" => {
#          "title" => "SCP-106 - オールドマン",
#          "item_number" => "SCP-106",
#          "object_class" => "Keter",
#          "updated" => Time.parse("2019-01-18 05:39")
#        },
#        "scp-173" => {
#          "title" => "SCP-173 - 彫刻 - オリジナル",
#          "item_number" => "SCP-173",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2019-01-06 18:14")
#        },
#        "scp-231" => {
#          "title" => "SCP-231 - 特別職員要件",
#          "item_number" => "SCP-231",
#          "object_class" => "Keter",
#          "updated" => Time.parse("2018-12-29 12:29")
#        },
#        "scp-426" => {
#          "title" => "SCP-426 - 私はトースター",
#          "item_number" => "SCP-426",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2017-06-04 21:53")
#        },
#        "scp-682" => {
#          "title" => "SCP-682 - 不死身の爬虫類",
#          "item_number" => "SCP-682",
#          "object_class" => "Keter",
#          "updated" => Time.parse("2018-11-11 20:07")
#        },
#        "scp-914" => {
#          "title" => "SCP-914 - ぜんまい仕掛け",
#          "item_number" => "SCP-914",
#          "object_class" => "Safe",
#          "updated" => Time.parse("2017-12-01 18:01")
#        },
#        "scp-2000" => {
#          "title" => "SCP-2000 - 機械仕掛けの神",
#          "item_number" => "SCP-2000",
#          "object_class" => "Thaumiel",
#          "updated" => Time.parse("2018-09-25 16:39")
#        },
#        "scp-2317" => {
#          "title" => "SCP-2317 - 異世界への扉",
#          "item_number" => "SCP-2317",
#          "updated" => Time.parse("2019-01-18 23:53")
#        },
#        "scp-2602" => {
#          "title" => "かつて図書館だったSCP-2602",
#          "item_number" => "SCP-2602",
#          "object_class" => "Former",
#          "updated" => Time.parse("2017-05-16 15:27")
#        })
#    end
#
#    it "parse a page" do
#      data = @engine.parse("https://blog.example.com/pages/scp-173.html")
#
#      expect(data).to match(
#        "scp-173" => {
#          "title" => "SCP-173 - 彫刻 - オリジナル",
#          "item_number" => "SCP-173",
#          "object_class" => "Euclid",
#          "updated" => Time.parse("2019-01-06 18:14")
#        })
#    end
#  end

  class BlogListTestRule < Crawline::BaseRule
    def initialize(url, data)
      @url = url
      @data = data

      @result = parse
    end

    def redownload?
      true
    end

    def valid?
      (not @result["related_links"].empty?)
    end

    def related_links
      @result["related_links"]
    end

    private

    def parse
      result = { "related_links" => [] }

      doc = Nokogiri::HTML.parse(@data, nil, "UTF-8")

      doc.xpath("//li[@class='pages_link']/a").each do |a|
        result["related_links"].push(URI.join(@url, a["href"]).to_s)
      end

      doc.xpath("//div[@id='pager']/a").each do |a|
        result["related_links"].push(URI.join(@url, a["href"]).to_s)
      end

      result
    end
  end

  class BlogPageTestRule < Crawline::BaseRule
    def initialize(url, data)
      @url = url
      @data = data

      @result = parse
    end

    def redownload?
      (@result["updated"].year >= 2018)
    end

    def valid?
      (not @result["updated"].nil?)
    end

    def related_links
      []
    end

    private

    def parse
      result = {}

      doc = Nokogiri::HTML.parse(@data, nil, "UTF-8")

      doc.xpath("//div[@id='updated']").each do |div|
        result["updated"] = Time.parse(div.text)
      end

      result
    end
  end
end
