class BaseRule
  extend ActiveSupport::Concern

  def match_request?(request)
    raise "Not implemented."
  end

  def want_redownload?(latest_content)
    raise "Not implemented."
  end

  def parse(downloaded_content)
    raise "Not implemented."
  end

end

