require "nokogiri"

class BlogListTestParser < Crawline::BaseParser
  def initialize(url, data)
    # initialize receive url and data
    @url = url
    @data = data

    # Parsing at initialize
    _parse
  end

  def redownload?
    # Always download
    true
  end

  def valid?
    # Valid if related_links is not empty
    (not @related_links.empty?)
  end

  def related_links
    # Related links in blog page list
    @related_links
  end

  def parse(context)
    # No data in blog page list
  end

  private

  def _parse
    @related_links = []

    doc = Nokogiri::HTML.parse(@data["response_body"], nil, "UTF-8")

    doc.xpath("//li[@class='pages_link']/a").each do |a|
      @related_links.push(URI.join(@url, a["href"]).to_s)
    end

    doc.xpath("//div[@id='pager']/a").each do |a|
      @related_links.push(URI.join(@url, a["href"]).to_s)
    end
  end
end

class BlogPageTestParser < Crawline::BaseParser
  def initialize(url, data)
    # initialize receive url and data
    @url = url
    @data = data

    # Parsing at initialize
    _parse
  end

  def redownload?
    # Download when updated.year is after 2018
    (@updated.year >= 2018)
  end

  def valid?
    # Valid if title and item_number and updated are not empty
    ((not @title.empty?) &&
      (not @item_number.empty?) &&
      (not @updated.nil?))
  end

  def related_links
    # No related links in page
    nil
  end

  def parse(context)
    # Set result of parse to context
    context[@item_number.downcase] = {
      "title" => @title,
      "item_number" => @item_number,
      "updated" => @updated
    }

    context[@item_number.downcase]["object_class"] = @object_class if not @object_class.nil?
  end

  private

  def _parse
    doc = Nokogiri::HTML.parse(@data["response_body"], nil, "UTF-8")

    doc.xpath("//h1").each do |h1|
      @title = h1.text
    end

    doc.xpath("//div[@id='item_number']").each do |div|
      @item_number = div.text
    end

    doc.xpath("//div[@id='object_class']").each do |div|
      @object_class = div.text
    end

    doc.xpath("//div[@id='updated']").each do |div|
      @updated = Time.parse(div.text)
    end
  end
end

