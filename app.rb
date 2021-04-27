require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

enable :sessions

# before do
#     if (session[:id] == nil && ((request.path_info != '/') || (request.path_info != '/showlogin')))
#         redirect('/showlogin')
#     end
# end

# before do 
#     if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
#       redirect("/showlogin")
#     end
# end



get ('/') do
    if already_logged_in?() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM items")
        slim(:"store/index",locals:{items:result})
    else
        # session[:error] = nil
        slim(:"users/register")
    end
end

get('/showlogin') do
    if already_logged_in?() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM items")
        slim(:"store/index",locals:{items:result})
    else
        # session[:error] = nil
        slim(:"users/login")
    end
end


post('/login') do
    username = params[:username]
    password = params[:password]
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    
    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        session[:username] = username
        redirect('/store')
    else
        set_error("Password does not match with chosen username.")
        redirect('/showlogin')
    end
end

post('/users/new') do
    username = params[:username]
    password_confirm = params[:password_confirm]
    password = params[:password]
    wallet = 5000
    
    if (password == password_confirm)
        # lägg till användare
        password_digest = BCrypt::Password.create(password)
        db = SQLite3::Database.new("db/webshop.db")
        db.execute("INSERT INTO users (username,pwdigest,wallet) VALUES (?,?,?)",username,password_digest,wallet)
        redirect('/showlogin')
        
    else
        # felhantering
        set_error("Passwords do not match.")
        redirect('/')
    end
end

get('/logout') do 
    session.destroy
    redirect('/showlogin')
end

get('/store') do
    if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
        redirect("/showlogin")
    end
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items")
    slim(:"store/index",locals:{items:result})
end


get('/upload') do
    if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
        redirect("/showlogin")
    end
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM category")
    slim(:"store/new",locals:{category:result})
end

post('/upload') do
    # Check if user uploaded a file
    if params[:image] && params[:image][:filename]
        name = params[:name]
        price = params[:price]
        stock = params[:stock]
        filename = params[:image][:filename]
        file = params[:image][:tempfile]
        category_id = params[:category_id].to_i
        path = "./public/uploads/#{filename}"
        img_src = "uploads/#{filename}"
        
        # Write file to disk
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
        db = connect_to_db("db/webshop.db")
        # Sätter in item egenskaper
        result = db.execute("INSERT INTO items (name,stock,price,image,image_client) VALUES (?,?,?,?,?)",name,stock,price,path,img_src)
        # Tar det sista item_id från items
        result2 = db.execute("SELECT * FROM items").last
        item_id = result2["item_id"].to_i
        # Sätter in category_id och item_id värden in i item_category_relation
        result3 = db.execute("INSERT INTO item_category_relation (category_id,item_id) VALUES (?,?)",category_id,item_id)
        redirect('/store')
    end
end
get('/store/:id') do
    if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
        redirect("/showlogin")
    end
    id = params[:id].to_i
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items WHERE item_id = ?",id).first
    result2 = db.execute("SELECT * FROM item_category_relation WHERE item_id = ?",id).first
    category_id = result2["category_id"].to_i
    result3 = db.execute("SELECT * FROM category WHERE category_id = ?",category_id).first
    slim(:"store/show",locals:{result:result, category:result3})
end
post('/store/:id') do
    item_id = params[:id].to_i
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items WHERE item_id = ?",item_id).first
    name = result["name"]
    price = result["price"]
    image = result["image_client"]
    result2 = db.execute("INSERT INTO order_item (item_name,item_price,item_image) VALUES (?,?,?)",name,price,image)
    result3 = db.execute("SELECT * FROM order_item").last
    order_id = result3["order_id"].to_i
    result4 = db.execute("INSERT INTO order_user_relation (order_id,user_id) VALUES (?,?)",order_id,user_id)
    redirect('/store')
end
post('/store/:id/delete') do
    item_id = params[:id].to_i
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    db.execute("DELETE FROM items WHERE item_id = ?",item_id).first
    db.execute("DELETE FROM item_category_relation WHERE item_id = ?",item_id).first
    redirect('/store')
end

get('/order') do
    if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
        redirect("/showlogin")
    end
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM order_item INNER JOIN order_user_relation ON order_item.order_id = order_user_relation.order_id WHERE user_id = ?",user_id)
    slim(:"store/order",locals:{order:result})
end

post('/order') do
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT SUM(item_price) FROM order_item INNER JOIN order_user_relation ON order_item.order_id = order_user_relation.order_id  WHERE user_id = ?",user_id)
    result2 = db.execute("SELECT wallet FROM users WHERE id = ?",user_id)
    wallet = result2 - result
    db.execute("UPDATE users SET wallet = ? WHERE id = ?",wallet,user_id)
    redirect('/store')

end