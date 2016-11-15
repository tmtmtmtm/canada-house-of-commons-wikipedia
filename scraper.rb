#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

PARTIES = {
  "Conservative" => "conservative",
  "Liberal" => "liberal",
  "NDP" => "ndp",
  "Bloc Québécois" => "bloc_québécois",
  "Green" => "green_party",
  "FD" => "forces_et_démocratie",
}

def party_id(str)
  return if str.to_s.empty?
  return PARTIES[str] || abort("No such party: #{str}")
end

def noko_for(url)
  Nokogiri::HTML(open(URI.escape(URI.unescape(url))).read)
end

def date_from(str)
  return if str.to_s.empty?
  Date.parse(str).to_s rescue nil
end


def scrape_term(id, url)
  noko = noko_for(url)
  district = nil
  skip = 0

  noko.xpath('//table[.//tr[th[.="Electoral district"]]]').each do |table|
    table.xpath('.//tr[td]').each do |tr|
      unless skip.zero?
        skip -= 1
        next
      end

      tds = tr.css('td')
      next if tds[1].text == 'Vacant'

      state = tr.xpath('preceding::h3/span[@class="mw-headline"]').last.text
      district = tds[3].text.tidy if tds[3]

      data = {
        name: tds[1].at_css('a').text,
        wikiname: tds[1].xpath('.//a[not(@class="new")]/@title').text,
        party: tds[2].text.tidy,
        state: state,
        district: district,
        area: "%s (%s)" % [state, district],
        term: id,
      }
      data[:party_id] = party_id(data[:party])

      if matched = tds[1].text.match(/until (.*)/)
        data[:start_date] = date_from(matched.captures.first)
      end
      if matched = tds[1].text.match(/after (.*)/)
        data[:end_date] = date_from(matched.captures.first)
      end

      if rowspan = tds[1].attr('rowspan')
        skip = rowspan.to_i - 1
      end

      ScraperWiki.save_sqlite([:wikiname, :term], data)
    end
  end
end

terms = {
  '42' => 'https://en.wikipedia.org/wiki/List_of_House_members_of_the_42nd_Parliament_of_Canada',
  '41' => 'https://en.wikipedia.org/wiki/List_of_House_members_of_the_41st_Parliament_of_Canada',
}

terms.each do |id, url|
  scrape_term(id, url)
end

