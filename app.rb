require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'

enable :sessions

include Model

# Redirects user to login page if no user is logged in.
#
# @see Model#not_logged_in
before do 
    if not_logged_in() == true
      redirect("/showlogin")
    end
end


# Displays Register Page.
#
# @see Model#already_logged_in
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

# Displays Login Page.
#
# @see Model#already_logged_in
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

# Attempts login and updates the session.
#
# @see Model#user_login
post('/users') do
    username = params[:username]
    password = params[:password]
    user_login(username, password)
end

# Attempts registration of user.
#
# @see Model#user_register
post('/users/new') do
    username = params[:username]
    password_confirm = params[:password_confirm]
    password = params[:password]
    wallet = 5000
    user_register(username, password, password_confirm, wallet)
end

# Logs out user and destroys the session.
#
get('/logout') do 
    session.destroy
    redirect('/showlogin')
end

# Displays Main Page.
#
get('/store') do
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items")
    slim(:"store/index",locals:{items:result})
end

# Displays Upload Page.
#
# @see Model#is_admin
get('/new') do
    if is_admin() == true
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM category")
        slim(:"store/new",locals:{category:result})
    else
        redirect("/store")
    end
end

# Attempts to upload a new item to the store.
#
# @see Model#new_item
post('/store') do
    new_item()
end

# Displays Clicked Item.
#
get('/store/:id') do
    id = params[:id].to_i
    db = connect_to_db("db/webshop.db")
    result = db.execute("SELECT * FROM items WHERE item_id = ?",id).first
    result2 = db.execute("SELECT * FROM item_category_relation WHERE item_id = ?",id).first
    category_id = result2["category_id"].to_i
    result3 = db.execute("SELECT * FROM category WHERE category_id = ?",category_id).first
    slim(:"store/show",locals:{result:result, category:result3})
end

# Attempts to add a selected item to the user's order list.
#
# @see Model#add_item
post('/store/:id') do
    item_id = params[:id].to_i
    user_id = session[:id]
    add_item(item_id, user_id)
end

# Displays Edit Page.
#
# @see Model#is_admin
get('/store/:id/edit') do
    if is_admin() == true
        id = params[:id].to_i
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM category")
        result2 = db.execute("SELECT * FROM items WHERE item_id = ?",id).first
        slim(:"store/edit",locals:{category:result, result:result2})
    else
        redirect('store/:id')
    end
end

# Attempts edit of store item.
#
# @see Model#edit_item
post('/store/:id/edit') do
    edit_item()
end

# Attempts deletion of store item.
#
# @see Model#delete_item
post('/store/:id/delete') do
    delete_item()
end

# Displays Order Page.
#
get('/order') do
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    # Select all relevant item-information from all the orders that are connected to the user's user_id.
    result = db.execute("SELECT items.item_id, name, price, image_client FROM items INNER JOIN order_item_relation ON items.item_id = order_item_relation.item_id INNER JOIN order_user_relation ON order_item_relation.order_id = order_user_relation.order_id WHERE user_id = ?",user_id)
    # result = db.execute("SELECT * FROM order_item INNER JOIN order_user_relation ON order_item.order_id = order_user_relation.order_id WHERE user_id = ?",user_id)
    slim(:"order/index",locals:{order:result})
end

# Attempts purchase of order.
#
# @see Model#purchase_order
post('/order') do
    user_id = session[:id]
    purchase_order(user_id)
end