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

      WebMock.stub_request(:get, "http://test.crawline.u6k.me/301.html").to_return(
        body: "Response 301 Moved Permanently",
        status: [301, "Moved Permanently"],
        headers: {
          "Location" => "http://test.crawline.u6k.me/200.html"
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

    it "download with redirect" do
      download_result = @downloader.download_with_get("http://test.crawline.u6k.me/301.html")

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

    it "put web page data" do
      @repo.put_s3_object("put_test.txt", "put test")

      obj = @bucket.object("put_test.txt.latest")
      expect(obj.get.body.read(obj.size)).to eq("put test")
    end

    it "get web page data" do
      obj = @bucket.object("get_test.txt.latest")
      obj.put(body: "get test")

      data = @repo.get_s3_object("get_test.txt")

      expect(data).to eq("get test")
    end

    it "remove all cache data" do
      @repo.remove_s3_objects
    end
  end
end
