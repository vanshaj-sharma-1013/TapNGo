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

# Our Node backend (see backend/README.md). Local testing: run `npm run dev` there.
# Before an Android build, set this to the https Cloud Run URL: Android blocks plain http.
const BACKEND_URL := "http://localhost:8080"

const REQUEST_TIMEOUT := 15.0
const NAME_MIN := 3
const NAME_MAX := 16
const LEADERBOARD_SIZE := 50
const GOOGLE_POLL_SECONDS := 2.0
const GOOGLE_TIMEOUT_SECONDS := 300.0

var uid := ""
var email := ""
var display_name := ""
var email_verified := false

var _run_token := ""
var _google_session := ""
var _id_token := ""
var _refresh_token := ""
var _token_expires_at := 0.0


func _ready() -> void:
	_restore_session()


func is_signed_in() -> bool:
	return not _refresh_token.is_empty()


# A guest is a Firebase anonymous account: it has a uid (so a leaderboard entry) but no email.
func is_guest() -> bool:
	return is_signed_in() and email.is_empty()


# Playing needs a login: a guest, or an account whose email is verified.
func can_play() -> bool:
	return is_signed_in() and (email_verified or is_guest())


# Returns an error message, or "" if the name is fine.
func validate_name(name: String) -> String:
	if name.length() < NAME_MIN or name.length() > NAME_MAX:
		return "Username must be %d-%d characters." % [NAME_MIN, NAME_MAX]
	return ""


func sign_up(name: String, new_email: String, password: String) -> Dictionary:
	var name_error := validate_name(name)
	if not name_error.is_empty():
		return _failure("", name_error)
	if new_email.is_empty() or password.is_empty():
		return _failure("", "Enter your email and a password.")
	var linking := is_guest()
	var result: Dictionary
	if linking:
		# Upgrade the guest account in place, so its uid and leaderboard score carry over.
		var token := await _valid_token()
		if token.is_empty():
			return _failure("NETWORK")
		result = await _request(AUTH_URL + "update?key=" + API_KEY, HTTPClient.METHOD_POST, {
			"idToken": token, "email": new_email, "password": password,
			"displayName": name, "returnSecureToken": true})
	else:
		result = await _request(AUTH_URL + "signUp?key=" + API_KEY, HTTPClient.METHOD_POST, {
			"email": new_email, "password": password, "returnSecureToken": true})
	if not result.ok:
		return result
	_apply_tokens(result.data)
	email = new_email
	display_name = name
	email_verified = false
	if not linking:
		var update := await _request(AUTH_URL + "update?key=" + API_KEY, HTTPClient.METHOD_POST, {
			"idToken": _id_token, "displayName": name, "returnSecureToken": true})
		if update.ok:
			_apply_tokens(update.data)
	_save_session()
	auth_changed.emit()
	# The account exists even if the email fails; "notice" tells the player to resend.
	var sent := await send_verification()
	return {"ok": true, "notice": "" if sent.ok else "We couldn't send your code. " + str(sent.message)}


func sign_in(login_email: String, password: String) -> Dictionary:
	if login_email.is_empty() or password.is_empty():
		return _failure("", "Enter your email and password.")
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


# Creates an anonymous account with a random "Guest1234" name, no email needed.
func sign_in_as_guest() -> Dictionary:
	var result := await _request(AUTH_URL + "signUp?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"returnSecureToken": true})
	if not result.ok:
		return result
	_apply_tokens(result.data)
	email = ""
	email_verified = false
	display_name = "Guest%d" % randi_range(1000, 9999)
	var update := await _request(AUTH_URL + "update?key=" + API_KEY, HTTPClient.METHOD_POST, {
		"idToken": _id_token, "displayName": display_name, "returnSecureToken": true})
	if update.ok:
		_apply_tokens(update.data)
	_after_sign_in()
	return {"ok": true}


# Wired to the "Continue with Google" buttons. Opens a sign-in page from our backend in the
# browser, waits for it to hand back a Google token, then trades that token to Firebase.
# A guest who signs in this way keeps their uid and leaderboard score.
func sign_in_with_google() -> Dictionary:
	var session := Crypto.new().generate_random_bytes(16).hex_encode()
	_google_session = session
	if OS.shell_open(BACKEND_URL + "/auth/google?session=" + session) != OK:
		_google_session = ""
		return _failure("", "Couldn't open the browser.")

	var waited := 0.0
	while waited < GOOGLE_TIMEOUT_SECONDS:
		await get_tree().create_timer(GOOGLE_POLL_SECONDS).timeout
		waited += GOOGLE_POLL_SECONDS
		if _google_session != session:
			return _failure("", "Google sign-in cancelled.")
		var poll := await _request(BACKEND_URL + "/auth/google/result?session=" + session, HTTPClient.METHOD_GET)
		if _google_session != session:
			return _failure("", "Google sign-in cancelled.")
		if poll.ok:
			if poll.data.has("idToken"):
				_google_session = ""
				return await _finish_google(str(poll.data.idToken))
		elif not poll.error in ["NETWORK", "RATE_LIMITED"]:
			_google_session = ""
			return poll
	_google_session = ""
	return _failure("", "Google sign-in timed out. Try again.")


# Stops a Google sign-in that is still waiting for the browser.
func cancel_google() -> void:
	_google_session = ""


func _finish_google(google_token: String) -> Dictionary:
	var url := AUTH_URL + "signInWithIdp?key=" + API_KEY
	var body := {
		"postBody": "id_token=%s&providerId=google.com" % google_token,
		"requestUri": "http://localhost",
		"returnSecureToken": true,
	}
	var linking := is_guest()
	if linking:
		var token := await _valid_token()
		if not token.is_empty():
			body["idToken"] = token
	var result := await _request(url, HTTPClient.METHOD_POST, body)
	if not result.ok and linking and result.error in ["FEDERATED_USER_ID_ALREADY_LINKED", "EMAIL_EXISTS"]:
		# That Google account already has a Tap N Go account: sign into it instead.
		body.erase("idToken")
		result = await _request(url, HTTPClient.METHOD_POST, body)
	if not result.ok:
		return result

	_apply_tokens(result.data)
	email = str(result.data.get("email", ""))
	# Google names are often longer than the leaderboard allows.
	var player_name := str(result.data.get("displayName", "")).strip_edges()
	if not validate_name(player_name).is_empty():
		player_name = player_name.left(NAME_MAX).strip_edges()
		if player_name.length() < NAME_MIN:
			player_name = "Player%d" % randi_range(1000, 9999)
		var update := await _request(AUTH_URL + "update?key=" + API_KEY, HTTPClient.METHOD_POST, {
			"idToken": _id_token, "displayName": player_name, "returnSecureToken": true})
		if update.ok:
			_apply_tokens(update.data)
	var profile := await _load_profile()
	if not profile.ok:
		sign_out()
		return profile
	_after_sign_in()
	return {"ok": true}


func sign_out() -> void:
	uid = ""
	email = ""
	display_name = ""
	email_verified = false
	_id_token = ""
	_refresh_token = ""
	_run_token = ""
	_token_expires_at = 0.0
	if FileAccess.file_exists(AUTH_PATH):
		DirAccess.remove_absolute(AUTH_PATH)
	auth_changed.emit()


# Emails a 6-digit code (backend /otp/send).
func send_verification() -> Dictionary:
	return await _backend_post("/otp/send", {})


# Checks the code the player typed (backend /otp/verify).
func verify_code(code: String) -> Dictionary:
	var result := await _backend_post("/otp/verify", {"code": code})
	if result.ok:
		email_verified = true
		# Fetch a token that carries the verified flag; the backend checks it on score submits.
		await _refresh_id_token()
		_save_session()
		auth_changed.emit()
	return result


# Call when an endless run begins. Scores are only accepted for a run the backend knows.
func start_run() -> void:
	_run_token = ""
	if not can_play():
		return
	var result := await _backend_post("/runs/start", {})
	if result.ok:
		_run_token = str(result.data.get("run", ""))


# Reports the run's distance. The backend rejects impossible scores and ones that don't
# beat the stored best, so a failed call is normal and safe to ignore.
func submit_score(score: int) -> Dictionary:
	if _run_token.is_empty() or score <= 0:
		return _failure("", "No active run.")
	return await _backend_post("/runs/finish", {"run": _run_token, "score": score})


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


func _backend_post(path: String, body: Dictionary) -> Dictionary:
	var token := await _valid_token()
	if token.is_empty():
		return _failure("NETWORK")
	return await _request(BACKEND_URL + path, HTTPClient.METHOD_POST, body, token)


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
	# Our own server being down reads differently from the player having no internet.
	var offline_error := "SERVER_UNREACHABLE" if url.begins_with(BACKEND_URL) else "NETWORK"
	if http.request(url, headers, method, payload) != OK:
		http.queue_free()
		return _failure(offline_error)
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return _failure(offline_error)
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	var code: int = response[1]
	if code >= 200 and code < 300:
		return {"ok": true, "data": parsed}
	var error := "UNKNOWN"
	if parsed is Dictionary and parsed.get("error") is Dictionary:
		# Firebase messages look like "WEAK_PASSWORD : Password should be at least 6 characters".
		error = str(parsed.error.get("message", "UNKNOWN")).get_slice(" ", 0)
	elif parsed is Dictionary and parsed.get("error") is String:
		# Our backend sends the code directly: {"error": "INVALID_CODE"}.
		error = parsed.error
	return _failure(error)


func _failure(error: String, message := "") -> Dictionary:
	if not error.is_empty() and error != "NETWORK":
		# The raw code is for whoever is debugging; players only see the friendly text.
		push_warning("Cloud error: " + error)
	return {"ok": false, "error": error, "message": message if not message.is_empty() else _friendly(error)}


func _friendly(error: String) -> String:
	match error:
		"EMAIL_EXISTS":
			return "That email already has an account. Try logging in instead."
		"INVALID_EMAIL", "MISSING_EMAIL":
			return "That email address doesn't look right."
		"WEAK_PASSWORD", "MISSING_PASSWORD":
			return "Password must be at least 6 characters."
		"INVALID_LOGIN_CREDENTIALS", "EMAIL_NOT_FOUND", "INVALID_PASSWORD":
			return "Wrong email or password."
		"USER_DISABLED":
			return "This account has been disabled."
		"TOO_MANY_ATTEMPTS_TRY_LATER":
			return "Too many attempts. Please wait a while and try again."
		"OPERATION_NOT_ALLOWED", "PASSWORD_LOGIN_DISABLED", "ADMIN_ONLY_OPERATION":
			return "This way of signing in isn't available right now. Try another option."
		"TOKEN_EXPIRED", "CREDENTIAL_TOO_OLD_LOGIN_AGAIN", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND":
			return "Your session expired. Please log in again."
		"QUOTA_EXCEEDED":
			return "Too many people are signing up right now. Try again later."
		"NOT_VERIFIED":
			return "Verify your email first."
		"NO_EMAIL":
			return "This account has no email to verify."
		"SERVER_UNREACHABLE":
			return "Can't reach the game server. Check your internet and try again."
		"INVALID_CODE":
			return "Wrong code. Try again."
		"CODE_EXPIRED":
			return "That code expired. Tap Resend code."
		"TOO_MANY_CODE_ATTEMPTS":
			return "Too many wrong codes. Tap Resend code for a new one."
		"RESEND_TOO_SOON":
			return "Wait a minute before asking for another code."
		"EMAIL_FAILED":
			return "Couldn't send the email. Try again later."
		"RATE_LIMITED":
			return "Too many requests. Wait a moment."
		"UNAUTHENTICATED":
			return "Please log in again."
		"GOOGLE_NOT_CONFIGURED":
			return "Google sign-in isn't set up on the server yet."
		"INVALID_IDP_RESPONSE":
			return "Google sign-in failed. Try again."
		"NETWORK":
			return "No connection. Check your internet."
	return "Something went wrong. Please try again."
