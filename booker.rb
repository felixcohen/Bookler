require 'initialiser'

get '/book/:id' do
  @book = Book.find(params[:id])
  haml :book
end

post '/' do
   feedurl = params[:feedurl]
   dname = params[:dname]
   dpass = params[:dpass]
   delicious = Rdelicious.new(dname, dpass)
   posts = []
   @chapters = []
   feed = FeedNormalizer::FeedNormalizer.parse open(feedurl)
  feed.entries.each do |post|
    puts post.urls.first.index(/[jpg|png|gif]/)
    puts post.urls.first
    if ((post.urls.first.include? 'jpg') || (post.urls.first.include? 'png') || (post.urls.first.include? 'gif'))
      @chapters.push("content"=>"<img src=\""+post.urls.first+"\">")
    else  
      url = 'http://felixcohen.co.uk/readability.php?url='+post.urls.first
      begin
        page = open(url)
      rescue StandardError=>e
        puts "Error: #{e}"
      else
        text = rpage.read
      ensure   
        puts url
      end
      @chapters.push("title"=>post.title,"content"=>text)
    end
    delicious.add(post.urls.first,post.title,'','madeintoabook') if delicious.is_connected?
  end
  
    template = File.read('views/book.haml')
    haml_engine = Haml::Engine.new(template)
    output = haml_engine.render(Object.new, :@chapters => @chapters)
    puts output
    file = "/tmp/"+feedurl+".pdf"
      prince = Prince.new
      prince.add_style_sheets("views/print.css")
     prince.html_to_file(output, file)
     send_file(
      file,
       :filename => '/tmp/'+feedurl+'.pdf',
       :type => 'application/pdf'
     )
  end
  
get '/' do
  haml :index
end

get '/about' do
  haml :about
end

get '/books' do
  @books = Book.all :limit => 10
  haml :books
end

post '/book' do
  book = Book.create(:title => params[:title], :url => params[:feedurl])
  book.save
  redirect '/book/'+book.id.to_s
end
