require 'rubygems'
require 'sinatra'
require 'haml'
require 'feed-normalizer'
require 'json'
require 'open-uri'
require 'digest/md5'
require 'rdelicious'
require 'active_record'
require 'delayed_job'
require './init'
require 'readability'
require 'uuid'
require 'fileutils'
require 'log_buddy'

configure do
  config = YAML::load(File.open('config/database.yml'))
  environment = 'development'
    ActiveRecord::Base.establish_connection(
    config[environment]
  )

  LogBuddy.init :disabled => environment == "production"
end

Delayed::Worker.max_run_time = 900
Delayed::Worker.backend = :active_record


class Book < ActiveRecord::Base
  after_create :queue
  
  def queue
    Delayed::Job.enqueue self
  end
  
  def perform
    posts = []
    @chapters = []
    title = self.title
    feed = FeedNormalizer::FeedNormalizer.parse open(self.url)
    feed.entries.each do |post|
      d { post.urls.first }
      if ((post.urls.first.include? 'jpg') || (post.urls.first.include? 'png') || (post.urls.first.include? 'gif'))
        @chapters.push("content"=>"<img src=\""+post.urls.first+"\">")
      else  
      begin
        url = 'http://felixcohen.co.uk/readability.php?url='+post.urls.first
        text = ''
        timeout(10) do
            text = open(post.urls.first).read
        end
        text = Readability::Document.new(text, :tags => %w[div p img a br li ul span], 
                                               :attributes => %w[src href]
                                               ).content
        @chapters.push("title"=>post.title,"content"=>text)
        rescue OpenURI::HTTPError => ex
              puts "Uh oh, we couldnt find that page"
              next
        end
      end
    end
    template = File.read('views/chapters.haml')
    haml_engine = Haml::Engine.new(template)
    self.content = haml_engine.render(Object.new, :@chapters => @chapters, :self_title => self.title)
    princely = Princely::Prince.new()
    princely.add_style_sheets('./public/print.css')

    # don't store a pdf in the database. Instead create a uuid, make a direct with that name, then store 
    # it in there, as book.pdf, like public/books/LONG_UUID/book.pdf
    store_pdf(princely.pdf_from_string(self.content))
    self.save
  end

  # 
  # Store pdf in directory instead of database, and 
  # link to the pdf filepath instead.
  # @param [String] the pdf presented as a stream
  #
  def store_pdf (pdf)
    uuid = UUID.new
    # create a uuid to the directory name
    pdf_directory = uuid.generate 

    self.pdf = "/downloads/#{pdf_directory}/book.pdf" 

    d "creating directory: #{pdf_directory}"
    FileUtils.mkdir_p "public/downloads/#{pdf_directory}"

    d "writing pdf to public/downloads/#{pdf_directory}/book.pdf"
    File.open "public/downloads/#{pdf_directory}/book.pdf", "w" do |f|
      f << pdf
    end

    self.save
  end
    
end
