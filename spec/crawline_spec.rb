require "spec_helper"
require "webmock/rspec"
require "aws-sdk-s3"

describe "Crawline" do
  it "has a version number" do
    expect(Crawline::VERSION).not_to be nil
  end

  describe "Downloader" do
    before do
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
      download_result = Crawline::Downloader.download_with_get("http://test.crawline.u6k.me/200.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download with redirect" do
      download_result = Crawline::Downloader.download_with_get("http://test.crawline.u6k.me/301.html")

      expect(download_result).to eq("Response 200 OK")
    end

    it "download fail with 4xx" do
      expect {
        Crawline::Downloader.download_with_get("http://test.crawline.u6k.me/404.html")
      }.to raise_error(RuntimeError, "404 Not Found")
    end

    it "download fail with 5xx" do
      expect {
        Crawline::Downloader.download_with_get("http://test.crawline.u6k.me/500.html")
      }.to raise_error(RuntimeError, "500 Internal Server Error")
    end

    it "download fail with timeout" do
      expect {
        Crawline::Downloader.download_with_get("http://test.crawline.u6k.me/timeout")
      }.to raise_error(Net::OpenTimeout)
    end
  end

  describe "ResourceRepository" do
    it "put web page data" do
      bucket = get_s3_bucket

      Crawline::ResourceRepository.put_s3_object(bucket, "put_test.txt", "put test")

      obj = bucket.object("put_test.txt")
      expect(obj.get.body.read(obj.size)).to eq("put test")
    end

    it "get web page data" do
      bucket = get_s3_bucket

      obj = bucket.object("get_test.txt")
      obj.put(body: "get test")

      data = Crawline::ResourceRepository.get_s3_object(bucket, "get_test.txt")

      expect(data).to eq("get test")
    end

    def get_s3_bucket
      Aws.config.update({
        region: ENV["AWS_S3_REGION"],
        credentials: Aws::Credentials.new(ENV["AWS_S3_ACCESS_KEY"], ENV["AWS_S3_SECRET_KEY"])
      })
      s3 = Aws::S3::Resource.new(endpoint: ENV["AWS_S3_ENDPOINT"], force_path_style: ENV["AWS_S3_FORCE_PATH_STYLE"])

      bucket = s3.bucket(ENV["AWS_S3_BUCKET"])
      bucket.create if not bucket.exists?

      bucket
    end
  end
end
