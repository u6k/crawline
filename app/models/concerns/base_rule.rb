class BaseRule
  extend ActiveSupport::Concern

  def match_request?(request)
    raise "Not implemented."
  end

end

