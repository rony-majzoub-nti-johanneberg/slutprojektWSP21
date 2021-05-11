module Model
  # Connects to database and returns result as hash.
  #
  # @param [String] path The path of the database.
  def connect_to_db(path)
      db = SQLite3::Database.new(path)
      db.results_as_hash = true
      return db
  end

  # Checks if the typed username exists in the database.
  #
  # @param  [String] q The username typed by the user.
  def name_exist(q)
    db = connect_to_db("db/webshop.db")
    return db.execute("SELECT * FROM users WHERE username = ?",q).first
  end

  # Checks if a user is already logged in.
  def already_logged_in()
      if session[:id] != nil
        return true
      else
        return false
      end
  end

  # Displays an error message.
  #
  # @param [String] string The error message to show on-screen.
  def set_error(string)
      session[:error] = string
      return session[:error]
  end

  # Checks if a user is not currently logged in.
  def not_logged_in()
    if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/users') && (request.path_info != '/users/new'))
      return true
    else
      return false
    end
  end

  # Checks if the current session[:id] belongs to the admin.
  def is_admin()
    if session[:id] == 1
      return true
    else
      return false
    end
  end

  # Attempts login and updates the session.
  def user_login()
    username = params[:username]
    password = params[:password]
    if name_exist(username) != nil
        db = connect_to_db("db/webshop.db")
        result = db.execute("SELECT * FROM users WHERE username = ?",username).first
        pwdigest = result["pwdigest"]
        id = result["id"]
        
        # If credentials match the database, let the user proceed.
        if BCrypt::Password.new(pwdigest) == password
            session[:id] = id
            session[:username] = username
            set_error("")
            redirect('/store')
        else
            # If password does not match, send an error message.
            set_error("Password does not match with chosen username.")
            redirect('/showlogin')
        end
    else
        # If the user does not exist, send an error message.
        set_error("Password does not match with chosen username.")
        redirect('/showlogin')
    end
  end
  # Attempts registration of user.
  def user_register()
    username = params[:username]
    password_confirm = params[:password_confirm]
    password = params[:password]
    wallet = 5000
    if name_exist(username) == nil

        if (password == password_confirm)
            # If credentials are correct, create a new user with a set amount of money in their wallet.
            password_digest = BCrypt::Password.create(password)
            db = SQLite3::Database.new("db/webshop.db")
            db.execute("INSERT INTO users (username,pwdigest,wallet) VALUES (?,?,?)",username,password_digest,wallet)
            set_error("")
            redirect('/showlogin')
            
        else
            # If credentials are incorrect, send an error message.
            set_error("Passwords do not match.")
            redirect('/')
        end
    else
        set_error("Username has already been taken.")
        redirect('/')
    end
  end

  # Attempts to insert a new store-item in the database.
  def new_item()
    # Check if user uploaded a file
    if params[:image] && params[:image][:filename] != nil
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
    else
        set_error("You must upload an image file.")
        redirect('/new')
    end
  end

  # Attempts to add a selected item to the user's order list.
  def add_item()
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

  # Attempts to edit a selected store-item in the database.
  def edit_item()
    if is_admin() == true
        # Check if user uploaded a file
        if params[:image] && params[:image][:filename] != nil
            id = params[:id].to_i
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
            # # Sätter in item egenskaper
            # result = db.execute("INSERT INTO items (name,stock,price,image,image_client) VALUES (?,?,?,?,?)",name,stock,price,path,img_src)
            # # Tar det sista item_id från items
            # result2 = db.execute("SELECT * FROM items").last
            # item_id = result2["item_id"].to_i
            # # Sätter in category_id och item_id värden in i item_category_relation
            # result3 = db.execute("INSERT INTO item_category_relation (category_id,item_id) VALUES (?,?)",category_id,item_id)
            result = db.execute("UPDATE items SET name = ?, stock = ?, price = ?, image = ?, image_client = ? WHERE item_id = ?",name,stock,price,path,img_src,id)
            result2 = db.execute("UPDATE item_category_relation SET category_id = ? WHERE item_id = ?",category_id,id)
            redirect('/store')
        else
            set_error("You must upload an image file.")
            redirect('/store/:id/edit')
        end
    else
        redirect('store/:id')
    end
  end

  # Attempts to delete a selected store-item in the database.
  def delete_item()
    # Only execute if the user is an admin.
    if is_admin() == true
      item_id = params[:id].to_i
      user_id = session[:id]
      db = connect_to_db("db/webshop.db")
      db.execute("DELETE FROM items WHERE item_id = ?",item_id).first
      db.execute("DELETE FROM item_category_relation WHERE item_id = ?",item_id).first
      result = db.execute("SELECT order_id FROM order_item_relation WHERE item_id = ?",item_id).first
      if result != nil
          order_id = result["order_id"].to_i
          db.execute("DELETE FROM order_user_relation WHERE order_id = ?",order_id).first
          db.execute("DELETE FROM order_item_relation WHERE item_id = ?",item_id).first
      end
      redirect('/store')
    # If the user is not an admin, redirect them back to the item's page.
    else
        redirect('store/:id')
    end
  end

  # Attempts purchase of order.
  def purchase_order()
    user_id = session[:id]
    db = connect_to_db("db/webshop.db")
    # Subtract the cost of all the items from the user's wallet.
    db.execute("UPDATE users SET wallet = wallet - (SELECT SUM(price) FROM items INNER JOIN order_item_relation ON items.item_id = order_item_relation.item_id INNER JOIN order_user_relation ON order_item_relation.order_id = order_user_relation.order_id WHERE user_id = ?) WHERE id = ?",user_id,user_id)
    # Delete the remaining trash-data that is no longer relevant after purchase.
    db.execute("DELETE FROM order_item_relation WHERE order_id IN (SELECT order_id FROM order_user_relation WHERE user_id = ?)",user_id)
    db.execute("DELETE FROM order_user_relation WHERE user_id = ?",user_id)
    redirect('/store')
  end
end