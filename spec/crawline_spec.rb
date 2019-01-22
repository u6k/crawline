require "spec_helper"

describe Crawline do
  it "has a version number" do
    expect(Crawline::VERSION).not_to be nil
  end

  describe Downloader do
    it "download successful" do
      expect(false).to eq(true)
    end

    it "download with redirect" do
      expect(false).to eq(true)
    end

    it "download success with 3xx" do
      expect(false).to eq(true)
    end

    it "download fail with 4xx" do
      expect(false).to eq(true)
    end

    it "download fail with 5xx" do
      expect(false).to eq(true)
    end
  end

  describe ResourceRepository do
    it "put web page data" do
      expect(false).to eq(true)
    end
  end
end
