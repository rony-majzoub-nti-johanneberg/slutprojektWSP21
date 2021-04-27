def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end


def already_logged_in?() #Kollar om det för närvarande är någon användare inloggad.
    if session[:username] != nil
      return true
    else
      return false
    end
end

def set_error(string)
    session[:error] = string
    return session[:error]
  end
  