extends Node

# Autoload "Cloud": Firebase email/password accounts and the global endless leaderboard,
# using Firebase's REST APIs. The API key is a public identifier, not a secret: what
# players can read and write is controlled by the rules in firestore.rules.
#
# Every request function is a coroutine: `await` it. They return a Dictionary with
# "ok" (bool) and "message" (player-facing text when not ok).

signal auth_changed

const API_KEY := "AIzaSyDQFivzdMjXBsC4y-YK_m4tuuZ_E1osNuo"
const PROJECT_ID := "tapngo-4bed6"

const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/" + PROJECT_ID + "/databases/(default)/documents"
const AUTH_PATH := "user://auth.json"

const REQUEST_TIMEOUT := 15.0
const NAME_MIN := 3
const NAME_MAX := 16
const LEADERBOARD_SIZE := 50

var uid := ""
var email := ""
var display_name := ""
var email_verified := false

var _id_token := ""
var _refresh_token := ""
var _token_expires_at := 0.0


func _ready() -> void:
	_restore_session()


func is_signed_in() -> bool:
	return not _refresh_token.is_empty()


# Returns an error message, or "" if the name is fine.
func validate_name(name: String) -> String:
	if name.length() < NAME_MIN or name.length() > NAME_MAX:
		return "Username must be %d-%d characters." % [NAME_MIN, NAME_MAX]
	return ""


func sign_up(name: String, new_email: String, password: String) -> Dictionary:
	var name_error := validate_name(name)
	if not name_error.is_empty():
		return _failure("", name_error)
	var result := await _request(AUTH_URL + "signUp?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"email": new_email, "password": password, "returnSecureToken": true})
	if not result.ok:
		return result
	_apply_tokens(result.data)
	email = new_email
	display_name = name
	email_verified = false
	var update := await _request(AUTH_URL + "update?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"idToken": _id_token, "displayName": name, "returnSecureToken": true})
	if update.ok:
		_apply_tokens(update.data)
	_save_session()
	auth_changed.emit()
	send_verification()
	return {"ok": true}


func sign_in(login_email: String, password: String) -> Dictionary:
	var result := await _request(AUTH_URL + "signInWithPassword?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"email": login_email, "password": password, "returnSecureToken": true})
	if not result.ok:
		return result
	_apply_tokens(result.data)
	email = login_email
	var profile := await _load_profile()
	if not profile.ok:
		sign_out()
		return profile
	_after_sign_in()
	return {"ok": true}


# Wired to the "Continue with Google" buttons. Needs a Google Sign-In Android plugin first.
func sign_in_with_google() -> Dictionary:
	return _failure("", "Google sign-in is coming soon.")


func sign_out() -> void:
	uid = ""
	email = ""
	display_name = ""
	email_verified = false
	_id_token = ""
	_refresh_token = ""
	_token_expires_at = 0.0
	if FileAccess.file_exists(AUTH_PATH):
		DirAccess.remove_absolute(AUTH_PATH)
	auth_changed.emit()


func send_verification() -> Dictionary:
	var token := await _valid_token()
	if token.is_empty():
		return _failure("NETWORK")
	return await _request(AUTH_URL + "sendOobCode?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"requestType": "VERIFY_EMAIL", "idToken": token})


# Asks Firebase whether the player has opened the verification email yet.
func check_verified() -> Dictionary:
	var profile := await _load_profile()
	if profile.ok and email_verified:
		# The verified flag only reaches the leaderboard rules through a fresh token.
		await _refresh_id_token()
		_after_sign_in()
	return profile


# Saves the player's best distance. Rules only accept it from a verified account and
# only if it beats the stored one, so a failed call is normal and safe to ignore.
func submit_score(score: int) -> Dictionary:
	if not is_signed_in() or not email_verified or score <= 0:
		return _failure("", "Not signed in.")
	var token := await _valid_token()
	if token.is_empty():
		return _failure("NETWORK")
	var url := "%s/leaderboard/%s?updateMask.fieldPaths=name&updateMask.fieldPaths=score&updateMask.fieldPaths=updatedAt" % [
		FIRESTORE_URL, uid]
	return await _request(url, HTTPClient.METHOD_PATCH, {"fields": {
		"name": {"stringValue": display_name},
		"score": {"integerValue": str(score)},
		"updatedAt": {"timestampValue": Time.get_datetime_string_from_system(true) + "Z"},
	}}, token)


# On success the result has "entries": [{uid, name, score}], best first.
func fetch_top() -> Dictionary:
	var result := await _request(FIRESTORE_URL + ":runQuery?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"structuredQuery": {
			"from": [{"collectionId": "leaderboard"}],
			"orderBy": [{"field": {"fieldPath": "score"}, "direction": "DESCENDING"}],
			"limit": LEADERBOARD_SIZE,
		}})
	if not result.ok:
		return result
	var entries: Array = []
	for item in result.data:
		if item is Dictionary and item.has("document"):
			var fields: Dictionary = item.document.get("fields", {})
			entries.append({
				"uid": str(item.document.get("name", "")).get_file(),
				"name": str(fields.get("name", {}).get("stringValue", "?")),
				"score": int(fields.get("score", {}).get("integerValue", 0)),
			})
	return {"ok": true, "entries": entries}


func _after_sign_in() -> void:
	_save_session()
	auth_changed.emit()
	if email_verified and GameData.best_endless > 0:
		submit_score(GameData.best_endless)


func _load_profile() -> Dictionary:
	var token := await _valid_token()
	if token.is_empty():
		return _failure("NETWORK")
	var result := await _request(AUTH_URL + "lookup?key=" + API_KEY, HTTPClient.METHOD_POST, {"idToken": token})
	if not result.ok:
		return result
	var users: Array = result.data.get("users", [])
	if users.is_empty():
		return _failure("USER_NOT_FOUND")
	var user: Dictionary = users[0]
	uid = str(user.get("localId", uid))
	email = str(user.get("email", email))
	display_name = str(user.get("displayName", display_name))
	email_verified = bool(user.get("emailVerified", false))
	_save_session()
	return {"ok": true}


# Returns a usable ID token, refreshing it if it is about to expire. "" on failure.
func _valid_token() -> String:
	if not is_signed_in():
		return ""
	if Time.get_unix_time_from_system() >= _token_expires_at - 60.0:
		var result := await _refresh_id_token()
		if not result.ok:
			return ""
	return _id_token


func _refresh_id_token() -> Dictionary:
	var result := await _request(TOKEN_URL + "?key=" + API_KEY, HTTPClient.METHOD_POST,
		"grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode())
	if result.ok:
		_apply_tokens(result.data)
		_save_session()
	return result


func _restore_session() -> void:
	var file := FileAccess.open(AUTH_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or str(data.get("refresh_token", "")).is_empty():
		return
	_refresh_token = str(data.refresh_token)
	uid = str(data.get("uid", ""))
	email = str(data.get("email", ""))
	display_name = str(data.get("display_name", ""))
	email_verified = bool(data.get("email_verified", false))
	auth_changed.emit()
	# Refresh in the background. Offline keeps the saved account; a dead account signs out.
	var profile := await _load_profile()
	if profile.ok:
		if email_verified:
			await _refresh_id_token()
		_after_sign_in()
	elif profile.error in ["USER_NOT_FOUND", "USER_DISABLED", "TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN"]:
		sign_out()


func _save_session() -> void:
	var file := FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"refresh_token": _refresh_token,
		"uid": uid,
		"email": email,
		"display_name": display_name,
		"email_verified": email_verified,
	}))


# Accepts the sign-in/token responses, which spell their keys differently.
func _apply_tokens(data: Dictionary) -> void:
	_id_token = str(data.get("idToken", data.get("id_token", _id_token)))
	_refresh_token = str(data.get("refreshToken", data.get("refresh_token", _refresh_token)))
	uid = str(data.get("localId", data.get("user_id", uid)))
	_token_expires_at = Time.get_unix_time_from_system() + float(data.get("expiresIn", data.get("expires_in", 3600)))


# `body` is a Dictionary (sent as JSON) or a String (sent as a form).
func _request(url: String, method: int, body = null, token := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	var content_type := "application/x-www-form-urlencoded" if body is String else "application/json"
	var headers := PackedStringArray(["Content-Type: " + content_type])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var payload := ""
	if body is String:
		payload = body
	elif body != null:
		payload = JSON.stringify(body)
	if http.request(url, headers, method, payload) != OK:
		http.queue_free()
		return _failure("NETWORK")
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return _failure("NETWORK")
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	var code: int = response[1]
	if code >= 200 and code < 300:
		return {"ok": true, "data": parsed}
	var error := "UNKNOWN"
	if parsed is Dictionary and parsed.get("error") is Dictionary:
		# Messages look like "WEAK_PASSWORD : Password should be at least 6 characters".
		error = str(parsed.error.get("message", "UNKNOWN")).get_slice(" ", 0)
	return _failure(error)


func _failure(error: String, message := "") -> Dictionary:
	return {"ok": false, "error": error, "message": message if not message.is_empty() else _friendly(error)}


func _friendly(error: String) -> String:
	match error:
		"EMAIL_EXISTS":
			return "That email is already registered."
		"INVALID_EMAIL", "MISSING_EMAIL":
			return "Enter a valid email address."
		"WEAK_PASSWORD", "MISSING_PASSWORD":
			return "Password must be at least 6 characters."
		"INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD":
			return "Wrong email or password."
		"USER_DISABLED":
			return "This account has been disabled."
		"TOO_MANY_ATTEMPTS_TRY_LATER":
			return "Too many attempts. Try again later."
		"OPERATION_NOT_ALLOWED":
			return "Email sign-in is not enabled in Firebase."
		"NETWORK":
			return "No connection. Check your internet."
	return "Something went wrong (%s)." % error
