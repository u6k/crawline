require "spec_helper"
require "webmock/rspec"
require "aws-sdk-s3"

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
