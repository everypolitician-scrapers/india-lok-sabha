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

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table#ctl00_ContPlaceHolderMain_Alphabaticallist1_dg1 td.griditem a[href*="briefbio"]/@href').map(&:text).each do |link|
    scrape_person(URI.join(@URL, link))
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

  box1 = noko.css('#ctl00_ContPlaceHolderMain_Alphabaticallist1_Datagrid1')
  box2 = noko.css('#ctl00_ContPlaceHolderMain_Alphabaticallist1_DataGrid2')

  area, state  = unbracket box1.xpath('.//table//td[contains(.,"Constituency")]/following-sibling::td').text.gsub(/[[:space:]]+/, ' ').strip
  party, party_id = unbracket box1.xpath('.//table//td[contains(.,"Party")]/following-sibling::td').text.gsub(/[[:space:]]+/, ' ').strip
  internets = box1.xpath('.//table//td[contains(.,"Email")]/following-sibling::td/text()').map(&:text).map(&:strip)

  data = { 
    id: url.to_s[/mpsno=(\d+)/, 1],
    name: box1.css('.gridheader1').first.text.strip,
    party: party,
    party_id: party_id,
    area_state: state,
    constituency: area,
    email: internets.map(&:split).flatten.find { |t| t[/@/] },
    homepage: internets.map(&:split).flatten.find { |t| t[/http/] || t[/www/] },
    prior: noko.css('#ctl00_ContPlaceHolderMain_Alphabaticallist1_Label9').text[/Member\s+(.*?)\s+Lok Sabha/, 1],
    birth_date: date_from(box2.xpath('.//table//td[contains(.,"Date of Birth")]/following-sibling::td').text.strip),
    term: '16',
    image: noko.css('#ctl00_ContPlaceHolderMain_Alphabaticallist1_Image1/@src').text,
    source: url.to_s,
  }
  # puts data
  ScraperWiki.save_sqlite([:name, :term], data)
end

@URL = 'http://164.100.47.132/LssNew/Members/breif_alphalist.aspx'
scrape_list('cached.html')
