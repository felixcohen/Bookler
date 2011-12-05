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
require 'init'
require 'readability'


configure do
  config = YAML::load(File.open('config/database.yml'))
  environment = 'development'
  ActiveRecord::Base.establish_connection(
    config[environment]
  )
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
      puts post.urls.first.index(/[jpg|png|gif]/)
      puts post.urls.first
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
    self.pdf = princely.pdf_from_string(self.content)
    self.save
  end
  
  
end
