#!/bin/env ruby
# encoding: utf-8

require 'date'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def date_from(str)
  return if str.to_s.empty?
  return str if str[/^(\d{4})$/]
  Date.parse(str).to_s
end

def member_urls(url)
  noko = noko_for(url)
  noko.css('.member_list_table a/@href').map(&:text).uniq.select { |href| href.include? 'MemberBioprofile.aspx' }.map do |link|
    URI.join(url, link)
  end
end

# Erk
# expect("Foo (Bar)", "Foo", "Bar")
# expect("Foo (Bar )", "Foo", "Bar")
# expect("Foo ( Bar )", "Foo", "Bar")
# expect(" Foo ( Bar )", "Foo", "Bar")
# expect(" Foo ( Bar ) ", "Foo", "Bar")
# expect("Foo(Bar)", "Foo", "Bar")
# expect("Foo (Bar) (F(B))", "Foo (Bar)", "F(B)")
def unbracket(text)
  if m = text.match(/(.*)\((.*?\(.*?\))\)/)
    return m.captures.map(&:strip)
  elsif m = text.match(/(.*)\s*\(\s*(.*?)\s*\)/)
    return m.captures.map(&:strip)
  else
    return [m, nil]
  end
end

def scrape_person(url)
  noko = noko_for(url)

  area, state  = unbracket noko.xpath('.//table//td[contains(.,"Constituency")]/following-sibling::td').text.gsub(/[[:space:]]+/, ' ').strip
  party, party_id = unbracket noko.xpath('.//table//td[contains(.,"Party")]/following-sibling::td').text.gsub(/[[:space:]]+/, ' ').strip
  internets = noko.xpath('.//table//td[contains(.,"Email")]/following-sibling::td/text()').map(&:text).map(&:strip).map { |t| t.gsub('[AT]','@').gsub('[DOT]','.') }

  data = {
    id: url.to_s[/mpsno=(\d+)/, 1],
    name: noko.css('.gridheader1').first.text.strip,
    party: party,
    party_id: party_id,
    area_state: state,
    constituency: area,
    email: internets.map(&:split).flatten.find { |t| t[/@/] },
    homepage: internets.map(&:split).flatten.find { |t| t[/http/] || t[/www/] },
    birth_date: date_from(noko.xpath('.//table//td[contains(.,"Date of Birth")]/following-sibling::td').text.strip),
    term: '16',
    image: noko.css('#ContentPlaceHolder1_Image1/@src').text,
    source: url.to_s,
  }
  puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
  ScraperWiki.save_sqlite([:name, :term], data)
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
base = 'http://164.100.47.194/Loksabha/Members/AlphabeticalList.aspx'
member_urls(base).each do |url|
  scrape_person(url)
end
