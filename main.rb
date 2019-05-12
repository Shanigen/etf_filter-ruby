require 'nokogiri'
require 'pp'
require 'open-uri'
require 'date'

URL_OVERVIEW = 'https://www.justetf.com/uk/etf-profile.html?isin=%s&tab=overview'
               .freeze
URL_LISTING = 'https://www.justetf.com/uk/etf-profile.html?isin=%s&tab=listing'
              .freeze

def scrape_etf_overview(response)
  etf = {}
  # Use xpath for parsing
  etf[:name] = response.at('//span[@class="h1"]').text
  isin, ticker = response.search('//span[@class="identfier"]/span[@class="val"]')
                         .text.split(',')
  etf[:isin] = isin
  etf[:ticker] = ticker
  etf[:description] = response.at('//div[@class="col-sm-6"]/p').text
  etf[:last_quote] = response.at('//div[@class="col-xs-6"]/div[@class="val"]/span[2]')
                             .text
  etf[:one_year_low_high] = response.at('//div[@class="col-xs-6"]/div[@class="valchart"]')
                                    .text.strip.gsub(/\s+/, '/')
  etf[:fund_size] = response.at('//div[@class="row"]/div[@class="col-sm-6"]/div[@class="infobox"]/div/div[@class="col-xs-6"]/div[@class="val"]')
                            .text.strip.gsub(/\n+\t+/, '/')
  fs_category = response.at('//img[@class="uielem" and @data-toggle="tooltip"]')
                        .attr('src')[-5]
  etf[:fund_size_category] = fs_category == '1' ? 'low_cap' : fs_category == '2' ? 'mid_cap' : 'high_cap'
  etf[:replication] = response.at('//tr[1]/td/span[1]').text
  etf[:currency] = response.at('//table[@class="table"]/tbody/tr[4]/td[2]').text
  etf[:inception_date] = Time.parse(response.at('//table[@class="table"]/tbody/tr[7]/td[2]').text)
  etf[:ter] = response.at('//div[6]/div[2]/div[1]/div[1]/div[1]/div[1]').text
  etf[:distribution_policy] = response.at('//div[6]/div[2]/table/tbody/tr[1]/td[2]').text
  etf[:fund_domicile] = response.at('//div[6]/div[2]/table/tbody/tr[3]/td[2]').text
  etf
end

def scrape_etf_listing(response)
  etf = {}
  etf[:listings] = []
  response.search('//table/tbody/tr/td[1]').each do |listing|
    etf[:listings] << listing.text
  end
  etf
end

def scrape_etf(isin)
  etf = {}
  begin
    response = Nokogiri::HTML(open(format(URL_OVERVIEW, isin)))
    etf.merge!(scrape_etf_overview(response))
  rescue StandardError => e
    warn e
  end
  begin
    response = Nokogiri::HTML(open(format(URL_LISTING, isin)))
    etf.merge!(scrape_etf_listing(response))
  rescue StandardError => e
    warn e
  end
  etf
end

def suitable(etf)
  return false if etf[:distribution_policy] != 'Accumulating'

  return false if ['mid cap', 'high cap'].include? [:fund_size_category]

  return false unless etf[:replication].match('[pP]hysical')
   # at least 3 years old
  return false unless ((Time.now - etf[:inception_date]) / 86400).round >= 3 * 365

  true
end

begin
  File.open('suitable-etf.txt', 'w') do |output_file|
    File.open(ARGV[0], 'r') do |input_file|
      input_file.each_line do |line|
        etf = scrape_etf(line.strip)
        output_file.write(etf) if suitable(etf)
      end
    end
  end
rescue StandardError => e
  warn e
  warn 'usage: ruby etf.rb etf-list.txt'
end
