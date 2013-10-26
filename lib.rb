
require 'open-uri'
require 'nokogiri'
require 'json'
require 'digest/md5'
require 'pp'

def cache url
  filename = 'cache/' + Digest::MD5.hexdigest( url )
  if File.exists? filename
    open(filename).read
  else
    text = open(url).read
    File.open(filename,'w') do |f|
      f.write text
    end
    text
  end
end

def parse_citation c
  title     = c.css('.title a').text
  pubmed_id = c.css('.aux dd').first.text
  authors   = c.css('.supp .desc').first.text.split(/\s*,\s*/)
  {:title       => title,
   :id          => pubmed_id,
   :authors     => authors,
   :last_author => authors.last}
end

def citations pubmed_id, page = 0
  query_result = cache "http://www.ncbi.nlm.nih.gov/pubmed?linkname=pubmed_pubmed&from_uid=#{pubmed_id}"
  doc = Nokogiri::HTML.parse query_result
  pages = doc.xpath '//*[@id="maincontent"]/div/div[3]/div[2]/h2'
  pages.text =~ /Results: (\d+) to (\d+) of (\d+)/
  f, l, t = $1.to_i, $2.to_i, $3.to_i

  results = doc.css(".rslt")
  {:results => t, :first => f, :last => l, :citations => results.map {|c| parse_citation c } }
end

def meta_search term
  query_result = cache "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=0&usehistory=y&term=#{TERM}"
  parse1       = Nokogiri::XML.parse query_result
  webenv       = parse1.css("WebEnv").text
  querykey     = parse1.css("QueryKey").text

  {:webenv => webenv, :querykey => querykey}
end

def search webenv, querykey
  query2_text = cache "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=xml&query_key=#{querykey}&WebEnv=#{webenv}&retstart=0&retmax=#{RESULTS_MAX}"
  parse2      = Nokogiri::XML.parse(query2_text)

  doc_list = parse2.css("DocSum").map do |doc|
    top_level = [
      "Title",
      doc.css("Item[Name=Title]").text,

      "Last Author",
      doc.css("Item[Name=LastAuthor]").text,

      "authors",
      doc.css("Item[Name=Author]").map { |author|
        author.text
      },

      "Date",
      doc.css("Item[Name=PubDate]").text,

      "Journal",
      doc.css("Item[Name=FullJournalName]").text,

      "Pubmed id",
      doc.css("Id").text,

      "Pubtypes",
      doc.css("Item[Name=PubType]").map { |pt|
        pt.text
      },

      "DOI",
      doc.css("Item[Name=DOI]").text
    ]

    Hash[*top_level]
  end
end
