
-- DB Functions
IMPORT security
IMPORT util

IMPORT FGL gl_lib
IMPORT FGL lib_secure

SCHEMA njm_demo310

&include "mob_ws_lib.inc"
GLOBALS
	DEFINE g_user STRING
END GLOBALS
--------------------------------------------------------------------------------
FUNCTION db_connect()
	DEFINE l_dbname STRING
	DEFINE l_dbdriver STRING
	DEFINE l_ver INTEGER

	LET l_dbname = fgl_getEnv("DBNAME")
	IF l_dbname.getLength() < 2 THEN LET l_dbname = "njm_demo310" END IF
	LET l_dbdriver = fgl_getEnv("DBDRIVER")
	IF l_dbdriver = "dbmpgs" THEN
		LET l_dbname = "db+driver='"||l_dbdriver||"',source='"||l_dbname||"'"
	END IF
	CALL gl_lib.gl_logIt(SFMT("Trying to connect to %1 ...",l_dbname))
	TRY
		CONNECT TO l_dbname
		CALL gl_lib.gl_logIt(SFMT(%"Connected to %1",l_dbname))
	CATCH
		CALL gl_lib.gl_logIt(SFMT(%"ERROR: Failed to connect to %1\n%2",l_dbname,SQLERRMESSAGE))
		EXIT PROGRAM
	END TRY

	TRY
		CREATE TABLE ws_backend_ver (
			ver INTEGER
		)
		INSERT INTO ws_backend_ver VALUES( WS_VER )
	CATCH
		SELECT ver INTO l_ver FROM ws_backend_ver
		IF l_ver != WS_VER THEN
			CALL db_drops()
			DELETE FROM ws_backend_ver
			INSERT INTO ws_backend_ver VALUES( WS_VER )
		END IF
	END TRY
	CALL gl_lib.gl_logIt(SFMT(%"Backend DB Ver: %1",l_ver))

	TRY
		CREATE TABLE ws_users (
			username CHAR(30),
			pass_hash CHAR(60),
			salt CHAR(60),
			token CHAR(60),
			token_date DATETIME YEAR TO SECOND
		)
	CATCH
	END TRY

	TRY
		CREATE TABLE ws_log_access (
			key SERIAL,
			username CHAR(30),
			request VARCHAR(250),
			access_date DATETIME YEAR TO SECOND
		)
	CATCH
	END TRY

	TRY
		CREATE TABLE ws_log_media (
			key SERIAL,
			username CHAR(30),
			media_type CHAR(1),
			filepath VARCHAR(250),
			access_date DATETIME YEAR TO SECOND
		)
	CATCH
	END TRY

	TRY
		CREATE TABLE ws_log_data (
			key SERIAL,
			username CHAR(30),
			data TEXT,
			access_date DATETIME YEAR TO SECOND
		)
	CATCH
	END TRY

	TRY
		CREATE TABLE ws_media_details (
			key SERIAL,
			username CHAR(30),
			custid INTEGER,
			jobid CHAR(30),
			jobref CHAR(30),
			uri VARCHAR(100),
			filename VARCHAR(100),
			filesize INTEGER,
			type CHAR(10),
			timestamp DATETIME YEAR TO SECOND,
			id CHAR(40),
			sent_ok BOOLEAN,
			send_reply VARCHAR(100)
		)
	CATCH
	END TRY

END FUNCTION

--------------------------------------------------------------------------------
-- Drop the tables
-- 
FUNCTION db_drops()
	CALL gl_lib.gl_logIt(%"Dropping Backend DB Tables")
	DROP TABLE ws_users
	DROP TABLE ws_log_access
	DROP TABLE ws_log_media
	DROP TABLE ws_log_data
	DROP TABLE ws_media_details
END FUNCTION
--------------------------------------------------------------------------------
-- Log the access to the service
-- 
-- @params l_user User
-- @params l_pass Password
-- @returns the auth token or NULL if fails
FUNCTION db_log_access(l_user STRING, l_request STRING)
	DEFINE l_ws_log_access RECORD LIKE ws_log_access.*

	LET l_ws_log_access.access_date = CURRENT
	LET l_ws_log_access.username = l_user.trim()
	LET l_ws_log_access.request = l_request.trim()
	CALL gl_lib.gl_logIt(SFMT("db_log_access:%1 :%2",l_ws_log_access.username CLIPPED,l_ws_log_access.request))
	INSERT INTO ws_log_access VALUES l_ws_log_access.*

END FUNCTION
--------------------------------------------------------------------------------
-- Log the media files received
-- 
-- @params l_user User
-- @params l_path File path
-- @returns the auth token or NULL if fails
FUNCTION db_log_media(l_type CHAR(1), l_path STRING)
	DEFINE l_ws_log_media RECORD LIKE ws_log_media.*

	LET l_ws_log_media.access_date = CURRENT
	LET l_ws_log_media.username = g_user
	LET l_ws_log_media.media_type = l_type
	LET l_ws_log_media.filepath = l_path.trim()
	CALL gl_lib.gl_logIt(SFMT("db_log_media:%1:%2:%3",g_user, l_type, l_path.trim() ))
	INSERT INTO ws_log_media VALUES l_ws_log_media.*

END FUNCTION
--------------------------------------------------------------------------------
-- Log the data received
-- 
-- @params l_user User
-- @params l_path File path
-- @returns the auth token or NULL if fails
FUNCTION db_log_data(l_user STRING, l_data STRING)
	DEFINE l_ws_log_data RECORD LIKE ws_log_data.*
	DEFINE l_ws_media_details RECORD LIKE ws_media_details.*
	DEFINE l_info DYNAMIC ARRAY OF RECORD LIKE ws_media_details.*
	DEFINE l_media_path, l_media_uri STRING
	DEFINE x SMALLINT

	LET l_ws_log_data.access_date = CURRENT
	LET l_ws_log_data.username = l_user.trim()
	LOCATE l_ws_log_data.data IN MEMORY
	LET l_ws_log_data.data = l_data.trim()
	CALL gl_lib.gl_logIt(SFMT("db_log_data:%1:%2",l_user,l_data.trim()))
	INSERT INTO ws_log_data VALUES l_ws_log_data.*

	IF l_data.getCharAt(1) = "[" THEN
		TRY
			CALL util.JSON.parse(l_data, l_info)
			CALL gl_lib.gl_logIt(SFMT(%"Got Info:%1 media files",l_info.getLength()))
		CATCH
			CALL gl_lib.gl_logIt(SFMT(%"JSON Parse failed:%1",l_data))
			RETURN
		END TRY
	END IF

	LET l_media_path = fgl_getEnv("MEDIAPATH")
	LET l_media_uri = fgl_getEnv("MEDIAURI")
	IF l_media_uri IS NULL THEN LET l_media_uri = l_media_path END IF
	FOR x = 1 TO l_info.getLength()
		LET l_ws_media_details.* = l_info[x].*
		LET l_ws_media_details.username = l_user
		LET l_ws_media_details.uri = l_media_uri
		INSERT INTO ws_media_details VALUES l_ws_media_details.*
	END FOR

END FUNCTION
--------------------------------------------------------------------------------
-- Check the user is registered with that password or register new user
-- 
-- @params l_user User
-- @params l_pass Password
-- @returns the auth token or NULL if fails
FUNCTION db_check_user( l_user CHAR(30), l_pass CHAR(30) ) RETURNS STRING
	DEFINE l_token STRING
	DEFINE l_salt, l_pass_hash STRING
	DEFINE l_token_date, l_now DATETIME YEAR TO SECOND
	LET l_now = CURRENT
	SELECT pass_hash, salt, token, token_date
		INTO l_pass_hash, l_salt, l_token, l_token_date
		FROM ws_users WHERE username = l_user
	IF STATUS = NOTFOUND THEN
		IF fgl_getEnv("NEWUSERS") = 1 THEN -- do we allow new users to be created ?
			LET l_token = db_register_user(l_user,l_pass)
			CALL gl_lib.gl_logIt(SFMT(%"Registered user '%1' with token '%2'", l_user CLIPPED,l_token))
			RETURN l_token.trim()
		ELSE
			RETURN NULL
		END IF
	END IF
	IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
		CALL gl_lib.gl_logIt(SFMT(%"User '%1' password mismatch!", l_user CLIPPED))
		RETURN NULL
	END IF
	LET l_token = l_token.trim()
	IF l_token_date > ( l_now - 1 UNITS DAY ) THEN
		CALL gl_lib.gl_logIt(SFMT(%"User '%1' already registered with token '%2'", l_user CLIPPED,l_token))
		RETURN l_token
	ELSE
		LET l_token = security.RandomGenerator.CreateUUIDString()
		UPDATE ws_users SET ( token, token_date ) = ( l_token, l_now )
			WHERE username = l_user
		CALL gl_lib.gl_logIt(SFMT(%"User '%1' Registered already but token expired, new is '%2'", l_user CLIPPED,l_token))
	END IF
	RETURN l_token
END FUNCTION
--------------------------------------------------------------------------------
-- Register new user
--
-- @params l_user User
-- @params l_pass Password
-- @returns the auth token
FUNCTION db_register_user( l_user CHAR(30), l_pass CHAR(30)) RETURNS STRING
	DEFINE l_token STRING
	DEFINE l_now DATETIME YEAR TO SECOND
	DEFINE l_salt, l_pass_hash STRING
	LET l_now = CURRENT
	LET l_token = security.RandomGenerator.CreateUUIDString()
	LET l_salt = lib_secure.glsec_genSalt( NULL )
	LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
	INSERT INTO ws_users VALUES( l_user, l_pass_hash, l_salt, l_token, l_now )
	CALL db_log_access(l_user,"created")
	RETURN l_token
END FUNCTION
--------------------------------------------------------------------------------
-- Check the Token used is registered to a user and not expired.
--
-- @params l_token auth token
-- @returns user or ERROR: <reason>
FUNCTION db_check_token( l_token STRING ) RETURNS STRING
	DEFINE l_user STRING
	DEFINE l_token_date, l_now DATETIME YEAR TO SECOND

	IF l_token = "JustTesting" THEN RETURN "test" END IF

	SELECT username, token_date INTO l_user, l_token_date FROM ws_users WHERE token = l_token
	IF STATUS = NOTFOUND THEN
		RETURN SFMT(%"ERR: Invalid Token '%1'!",l_token)
	END IF

	LET l_now = CURRENT
	IF l_token_date > ( l_now - 1 UNITS DAY ) THEN
		RETURN l_user
	ELSE
		RETURN %"ERR: Token expired!"
	END IF
END FUNCTION


-- Example code:

--------------------------------------------------------------------------------
-- Get Customers - DUMMY CODE
--
-- @returns json string of the data
FUNCTION db_get_custs() RETURNS STRING
DEFINE l_list1 DYNAMIC ARRAY OF RECORD
		key CHAR(10),
		line1 CHAR(50),
		line2 CHAR(50)
	END RECORD

{
	DEFINE x SMALLINT

	FOR x = 1 TO 5
		LET l_list1[x].key = "TEST-"||x
		CASE x
			WHEN 1 LET l_list1[x].line1 = "Neil"
						LET l_list1[x].line2 = "20a Somewhere rd"
			WHEN 2 LET l_list1[x].line1 = "Paul"
						LET l_list1[x].line2 = "The Chapel"
			WHEN 3 LET l_list1[x].line1 = "John"
						LET l_list1[x].line2 = "1 Abbey Rd"
			WHEN 4 LET l_list1[x].line1 = "Mike"
						LET l_list1[x].line2 = "5 Smith Street"
			WHEN 5 LET l_list1[x].line1 = "Fred"
						LET l_list1[x].line2 = "10 Bloggs rd"
		END CASE
	END FOR
}

	DECLARE cust_list_cur CURSOR FOR SELECT customer_code, customer_name, contact_name
		FROM customer ORDER BY customer_name
	FOREACH cust_list_cur 
			INTO l_list1[ l_list1.getLength() + 1].key,
					 l_list1[ l_list1.getLength()].line1,
 					 l_list1[ l_list1.getLength()].line2
			LET l_list1[ l_list1.getLength()].line1 = l_list1[ l_list1.getLength() ].key CLIPPED||" "||l_list1[ l_list1.getLength()].line1
	END FOREACH
	CALL l_list1.deleteElement( l_list1.getLength() )
	CALL gl_lib.gl_logIt(SFMT("Found %1 Customers",l_list1.getLength()))

	RETURN util.JSON.stringify(l_list1)
END FUNCTION
--------------------------------------------------------------------------------
-- Get the details for the customer - DUMMY CODE
--
-- @params l_key Customer account no
-- @returns json string of the data
FUNCTION db_get_custDets(l_key STRING)
	DEFINE l_custDets RECORD LIKE customer.*

	SELECT * INTO l_custDets.* FROM customer WHERE customer_Code = l_key
	IF STATUS = NOTFOUND THEN
		LET l_custDets.customer_name = "Not Found!"
	END IF

	RETURN util.JSON.stringify(l_custDets)
END FUNCTION
--------------------------------------------------------------------------------
-- Get order for the customer - DUMMY CODE
--
-- @params l_key Customer account no
-- @returns json string of the data
FUNCTION db_get_orders(l_key STRING)
	DEFINE l_orders DYNAMIC ARRAY OF RECORD
		extra_data STRING
	END RECORD

	LET l_orders[1].extra_data = "Order #1 for acc ",l_key
	LET l_orders[2].extra_data = "Order #2 for acc ",l_key

	RETURN util.JSON.stringify(l_orders)
END FUNCTION
--------------------------------------------------------------------------------
-- Get order details for order no - DUMMY CODE
--
-- @params l_key Order No
-- @returns json string of the data
FUNCTION db_get_orderDets(l_key STRING)
	DEFINE l_order RECORD
		extra_data STRING
	END RECORD

	LET l_order.extra_data = "Order details for order: ",l_key

	RETURN util.JSON.stringify(l_order)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION db_get_media(l_key STRING)
	DEFINE l_file, l_id STRING
	DEFINE l_media DYNAMIC ARRAY OF STRING

	DECLARE media_cur CURSOR FOR SELECT filename,id FROM ws_media_details WHERE jobid = l_key
	FOREACH media_cur INTO l_file, l_id
		LET l_media[ l_media.getLength() + 1 ] = getURL(l_id.trim()||"/"||l_file.trim(),NULL)
	END FOREACH

	RETURN util.JSON.stringify(l_media)
END FUNCTION