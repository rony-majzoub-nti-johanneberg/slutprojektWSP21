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

before do 
    if not_logged_in() == true
      redirect("/showlogin")
    end
end



get ('/') do
    if already_logged_in() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM items")
        slim(:"store/index",locals:{items:result})
    else
        # session[:error] = nil
        slim(:"users/register")
    end
end

get('/showlogin') do
    if already_logged_in() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM items")
        slim(:"store/index",locals:{items:result})
    else
        # session[:error] = nil
        slim(:"users/login")
    end
end


post('/users') do
    username = params[:username]
    password = params[:password]
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    
    # If credentials match the database, let the user proceed.
    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        session[:username] = username
        redirect('/store')
    else
        # If credentials are incorrect, send an error message.
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
        # If credentials are correct, create a new user with a set amount of money in their wallet.
        password_digest = BCrypt::Password.create(password)
        db = SQLite3::Database.new("db/webshop.db")
        db.execute("INSERT INTO users (username,pwdigest,wallet) VALUES (?,?,?)",username,password_digest,wallet)
        redirect('/showlogin')
        
    else
        # If credentials are incorrect, send an error message.
        set_error("Passwords do not match.")
        redirect('/')
    end
end

get('/logout') do 
    # On logout, close the session and redirect to login screen.
    session.destroy
    redirect('/showlogin')
end

get('/store') do
    # Show all items on the main storepage.
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items")
    slim(:"store/index",locals:{items:result})
end


get('/new') do
    # Only execute if the user is an admin.
    if is_admin() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM category")
        slim(:"store/new",locals:{category:result})
    # If the user is not an admin, redirect them back to the main storepage.
    else
        redirect("/store")
    end
end

post('/store') do
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
    result2 = db.execute("INSERT INTO order_item_relation (item_id) VALUES (?)",item_id)
    result3 = db.execute("SELECT order_id FROM order_item_relation").last
    order_id = result3["order_id"].to_i
    result4 = db.execute("INSERT INTO order_user_relation (order_id,user_id) VALUES (?,?)",order_id,user_id)
    redirect('/store')
end
get('/store/:id/edit') do
    if is_admin() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM category")
        slim(:"store/new",locals:{category:result})
    else
        redirect('store/:id')
    end
end
post('/store/:id/delete') do
    # Only execute if the user is an admin.
    if is_admin() == true
        item_id = params[:id].to_i
        user_id = session[:id]
        db = connect_to_db("db/webshop.db")
        db.execute("DELETE FROM items WHERE item_id = ?",item_id).first
        db.execute("DELETE FROM item_category_relation WHERE item_id = ?",item_id).first
        result = db.execute("SELECT order_id FROM order_item_relation WHERE item_id = ?",item_id).first
        order_id = result["order_id"].to_i
        db.execute("DELETE FROM order_user_relation WHERE order_id = ?",order_id).first
        db.execute("DELETE FROM order_item_relation WHERE item_id = ?",item_id).first
        redirect('/store')
    # If the user is not an admin, redirect them back to the item's page.
    else
        redirect('store/:id')
    end
end

get('/order') do
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    # Select all relevant item-information from all the orders that are connected to the user's user_id.
    result = db.execute("SELECT items.item_id, name, price, image_client FROM items INNER JOIN order_item_relation ON items.item_id = order_item_relation.item_id INNER JOIN order_user_relation ON order_item_relation.order_id = order_user_relation.order_id WHERE user_id = ?",user_id)
    # result = db.execute("SELECT * FROM order_item INNER JOIN order_user_relation ON order_item.order_id = order_user_relation.order_id WHERE user_id = ?",user_id)
    slim(:"order/index",locals:{order:result})
end

post('/order') do
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    # Subtract the cost of all the items from the user's wallet.
    db.execute("UPDATE users SET wallet = wallet - (SELECT SUM(price) FROM items INNER JOIN order_item_relation ON items.item_id = order_item_relation.item_id INNER JOIN order_user_relation ON order_item_relation.order_id = order_user_relation.order_id WHERE user_id = ?) WHERE id = ?",user_id,user_id)
    # Delete the remaining trash-data that is no longer relevant after purchase.
    db.execute("DELETE FROM order_item_relation WHERE order_id IN (SELECT order_id FROM order_user_relation WHERE user_id = ?)",user_id)
    db.execute("DELETE FROM order_user_relation WHERE user_id = ?",user_id)
    redirect('/store')
end