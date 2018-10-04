class Scraper
  extend ActiveSupport::Concern
  
  @@rules = []
  
  def self.add_rule(rule)
    @@rules << rule
  end

  def find_rule(request)
    rule = @@rules.find { |rule| rule.match_request?(request) }
  end

end

