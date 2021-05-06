# Kopplar till databasen och returnerar resultat som hashes.
def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

# Kollar om någon användare är redan inloggad.
def already_logged_in()
    if session[:id] != nil
      return true
    else
      return false
    end
end

# Funktion för att skriva in errormeddelanden för varje route.
def set_error(string)
    session[:error] = string
    return session[:error]
end

# Kollar om ingen användare är inloggad just nu.
def not_logged_in()
  if (session[:id] ==  nil) && (request.path_info != '/') && (request.path_info != '/showlogin' && (request.path_info != '/error')) 
    return true
  else
    return false
  end
end

# Kollar om användaren är admin (genom session[:id]).
def is_admin()
  if session[:id] == 1
    return true
  else
    return false
  end
end