require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

get ('/') do
    slim(:"users/register")
end

get('/showlogin') do
    slim(:"users/login")
end


post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new('db/webshop.db')
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    
    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        redirect('/store')
    else
        "Wrong password."
    end
end

post('/users/new') do
    username = params[:username]
    password_confirm = params[:password_confirm]
    password = params[:password]
    
    if (password == password_confirm)
        # lägg till användare
        password_digest = BCrypt::Password.create(password)
        db = SQLite3::Database.new("db/webshop.db")
        db.execute("INSERT INTO users (username,pwdigest) VALUES (?,?)",username,password_digest)
        redirect('/showlogin')
        
    else
        # felhantering
        "Password does not match."
    end
end

get('/store') do
    slim(:"store/index")
end

get('/store/new') do
    slim(:"store/new")
end
post('/store/new') do
    name = params[:name]
    price = params[:price]
    stock = params[:stock]
    filename = params[:image][:filename]
    file = params[:image][:tempfile]
    path = "./public/img/#{filename}"
    File.open(path, 'wb') do |f|
        f.write(file.read)
    end
    path = "img/#{filename}"
    db.execute("INSERT INTO item (name,stock,price,image) VALUES (?,?,?,?)",name,stock,price,path)
end

#post('/upload_item') do
    ##Skapa en sträng med join "./public/img/cat.png"
    #path = File.join("./public/img/",params[:file][:filename])
    #name = params[:name]
   # price = params[:price]
   # stock = params[:stock]
   # db = SQLite3::Database.new("db/webshop.db")
   # db.execute("INSERT INTO item (name,stock,price,image) VALUES (?,?,?,?)",name,stock,price,path)
    
   # #Spara bilden (skriv innehållet i tempfile till destinationen path)
   # File.write(path,File.read(params[:file][:tempfile]))
    
   # redirect('/upload_item')
#end

