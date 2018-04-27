-- Core Mobile Library Code

IMPORT util
IMPORT os

IMPORT FGL mob_ws_lib
IMPORT FGL gl_lib
IMPORT FGL lib_secure

CONSTANT DB_VER = 1

DEFINE m_init_db BOOLEAN
PUBLIC DEFINE m_connected BOOLEAN
PUBLIC DEFINE m_user STRING
PUBLIC DEFINE m_sel_list1 DYNAMIC ARRAY OF RECORD
		key STRING,
		line1 STRING,
		line2 STRING
	END RECORD
PUBLIC DEFINE m_sel_list2 DYNAMIC ARRAY OF RECORD
		key STRING,
		line1 STRING,
		line2 STRING
	END RECORD

PUBLIC DEFINE m_dets1 RECORD
		customer_code					char(8),
		customer_name					varchar(30,0),
		contact_name					varchar(30,0),
		email									varchar(100,0),
		web_passwd						char(10),
		del_addr							integer,
		inv_addr							integer,
		disc_code							char(2),
		credit_limit					integer,
		total_invoices				decimal(12,2),
		outstanding_amount		decimal(12,2),
		updated_date 					DATETIME YEAR TO SECOND
	END RECORD

PUBLIC DEFINE m_list1_date, m_list2_date DATETIME YEAR TO SECOND

FUNCTION init_app()
	DEFINE l_dbname STRING
	LET l_dbname = "mob_database.db"
	TRY
		CONNECT TO l_dbname
	CATCH
		CALL gl_lib.gl_winMessage("Error",SFMT(%"Failed to connect to '%1'!\n%2",l_dbname, SQLERRMESSAGE),"exclamation")
		RETURN
	END TRY

	IF NOT init_db() THEN
		CALL gl_lib.gl_winMessage("Error",SFMT(%"Failed to initialize '%1'!\n%2",l_dbname, SQLERRMESSAGE),"exclamation")
		RETURN
	END IF

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION init_db() RETURNS BOOLEAN
	DEFINE l_ver SMALLINT

	LET m_init_db = FALSE
	TRY
		SELECT version INTO l_ver FROM db_version
		IF l_ver = DB_VER THEN
			DISPLAY "DB Ver ",l_ver," Okay"
			RETURN TRUE
		END IF
	CATCH
		LET m_init_db = TRUE
		CREATE TABLE db_version (
			version SMALLINT
		)
		LET l_ver = DB_VER
	END TRY

	DISPLAY "Initializing DB ..."
	DELETE FROM db_version
	INSERT INTO db_version VALUES(DB_VER)
	TRY
		DROP TABLE users
	CATCH
	END TRY
	CREATE TABLE users (
		username CHAR(30),
		pass_hash CHAR(60),
		salt CHAR(60),
		token CHAR(60),
		token_date DATETIME YEAR TO SECOND
	)

	TRY
		DROP TABLE sel_list1
	CATCH
	END TRY
	CREATE TABLE sel_list1 (
		key CHAR(12),
		line1 CHAR(50),
		line2 CHAR(50)
	)

	TRY
		DROP TABLE sel_list2
	CATCH
	END TRY
	CREATE TABLE sel_list2 (
		key CHAR(12),
		line1 CHAR(50),
		line2 CHAR(50)
	)

	TRY
		DROP TABLE dets1
	CATCH
	END TRY
	CREATE TABLE dets1 (
		customer_code        char(8),
		customer_name        varchar(30,0),
		contact_name         varchar(30,0),
		email                varchar(100,0),
		web_passwd           char(10),
		del_addr             integer,
		inv_addr             integer,
		disc_code            char(2),
		credit_limit         integer,
		total_invoices       decimal(12,2),
		outstanding_amount   decimal(12,2),
		updated_date DATETIME YEAR TO SECOND
	)

	TRY
		DROP TABLE table_updated
	CATCH
	END TRY
	CREATE TABLE table_updated (
		table_name CHAR(20),
		updated_date DATETIME YEAR TO SECOND
	)

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION login() RETURNS BOOLEAN
	DEFINE l_user, l_pass STRING
	DEFINE l_token, l_salt, l_pass_hash, l_xml_creds STRING
	DEFINE l_now, l_token_date DATETIME YEAR TO SECOND 

	OPEN FORM mob_login FROM "mob_login"
	DISPLAY FORM mob_login
	DISPLAY "Welcome to a simple GeneroMobile demo" TO welcome
	DISPLAY IIF( check_network(), "Connected","No Connection") TO f_network

	IF m_init_db AND NOT check_network() THEN
		CALL gl_lib.gl_winMessage("Error","First time Login requires a network connection\nConnect to network and try again","exclamation")
		EXIT PROGRAM
	END IF

	WHILE TRUE
		INPUT BY NAME l_user, l_pass
		IF int_flag THEN EXIT PROGRAM END IF

		LET l_now = CURRENT
		LET l_salt = NULL
		SELECT pass_hash, salt, token, token_date  
			INTO l_pass_hash,l_salt, l_token, l_token_date
			FROM users WHERE username = l_user
		IF STATUS != NOTFOUND THEN
			IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
				CALL gl_lib.gl_winMessage("Error","Login Failed","exclamation")
				CONTINUE WHILE
			END IF 
			IF l_token_date > ( l_now - 1 UNITS DAY ) THEN EXIT WHILE END IF -- all okay, exit the while
		END IF
-- user not in DB or token expired - connect to server for login check / new token.
-- encrypt the username and password attempt
		LET l_xml_creds = lib_secure.glsec_encryptCreds(l_user, l_pass)
		IF l_xml_creds IS NULL THEN RETURN FALSE END IF
		LET l_token =  ws_getSecurityToken( l_xml_creds ) 
		IF l_token IS NULL THEN RETURN FALSE END IF
		IF l_salt IS NULL THEN
			LET l_salt = lib_secure.glsec_genSalt( NULL )
			LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
			INSERT INTO users VALUES(l_user, l_pass_hash, l_salt, l_token, l_now )
		ELSE
			UPDATE users SET ( token, token_date ) = ( l_token, l_now )
				WHERE username = l_user
		END IF
		EXIT WHILE
	END WHILE
	LET m_user = l_user
	LET mob_ws_lib.m_security_token = l_token
	CALL gl_lib.gl_logIt("Security Token is '"||NVL(l_token.trim(),"NULL")||"'")

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION check_network() RETURNS BOOLEAN
	DEFINE l_network STRING
	LET m_connected = FALSE

	IF ui.Interface.getFrontEndName() = "GDC" THEN
		LET m_connected = TRUE
		RETURN m_connected
	END IF

	CALL ui.Interface.frontCall("mobile", "connectivity", [], [l_network] )
	IF l_network = "WIFI" OR l_network = "MobileNetwork" THEN
		LET m_connected = TRUE
	END IF
	RETURN m_connected
END FUNCTION
--------------------------------------------------------------------------------
-- Take / Choose a Photo and send to the server
FUNCTION photo(l_take BOOLEAN)
  DEFINE l_photo_file, l_local_file, l_ret STRING
	DEFINE l_image BYTE

	OPEN WINDOW show_photo WITH FORM "show_photo"

	IF l_take THEN
		CALL ui.Interface.frontCall("mobile","takePhoto",[],[l_photo_file])
	ELSE
		CALL ui.Interface.frontCall("mobile","choosePhoto",[],[l_photo_file])
	END IF
	DISPLAY l_photo_file TO f_lpath
	DISPLAY l_photo_file TO f_photo

	LET l_local_file = util.Datetime.format( CURRENT, "%Y%m%d_%H%M%S.jpg" )
	TRY
		CALL fgl_getfile(l_photo_file,l_local_file)
	CATCH
		CALL gl_lib.gl_winMessage("Error",ERR_GET( STATUS ),"exclamation")
	END TRY
	DISPLAY l_local_file TO f_path
	IF os.path.exists( l_local_file ) THEN
		DISPLAY "Exists:"||l_local_file TO f_path
	ELSE
		DISPLAY "Missing:"||l_local_file TO f_path
	END IF
	DISPLAY os.path.size(l_local_file) TO f_size
	LOCATE l_image IN FILE l_local_file
	DISPLAY l_image TO f_photo

	MENU
		ON ACTION send
			IF check_network() THEN
				LET l_ret = mob_ws_lib.ws_putPhoto( l_local_file )
				IF l_ret IS NOT NULL THEN
					CALL gl_lib.gl_winMessage("Info",l_ret,"information")
				END IF
			ELSE
				CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
			END IF
		ON ACTION back EXIT MENU
	END MENU
	CLOSE WINDOW show_photo
END FUNCTION
--------------------------------------------------------------------------------
-- send some data to the server
FUNCTION send_data(l_data)
	DEFINE l_data, l_ret STRING

	IF check_network() THEN
		LET l_ret = mob_ws_lib.ws_sendData(l_data)
		IF l_ret IS NOT NULL THEN
			CALL gl_lib.gl_winMessage("Info",l_ret,"information")
		END IF
	ELSE
		CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_list1() RETURNS BOOLEAN
	DEFINE x SMALLINT
	DEFINE l_json STRING
	DEFINE l_user_local BOOLEAN
	DEFINE l_updated_date DATETIME YEAR TO SECOND
	DEFINE l_now DATETIME YEAR TO SECOND

	LET l_user_local = FALSE
	LET l_now = CURRENT
	SELECT updated_date INTO l_updated_date FROM table_updated WHERE table_name = "sel_list1"
	IF l_updated_date IS NOT NULL
	AND l_updated_date > ( l_now - 1 UNITS DAY ) THEN
		LET l_user_local = TRUE
	END IF

	IF NOT check_network() THEN  -- no connection
		IF NOT l_user_local AND l_updated_date IS NOT NULL THEN -- stale data
			CALL gl_lib.gl_winMessage("Warning",SFMT("Data is from %1\nYou are not connected to a network",l_updated_date),"exclamation")
			LET l_user_local = TRUE
		END IF
		IF l_updated_date IS NULL THEN -- no data
			CALL gl_lib.gl_winMessage("Error","No local data and no connection!","exclamation")
			LET m_list1_date = NULL
			RETURN FALSE
		END IF
	END IF

	IF l_user_local THEN
		CALL m_sel_list1.clear()
		DECLARE cust_cur CURSOR FOR SELECT * FROM sel_list1
		FOREACH cust_cur INTO m_sel_list1[ m_sel_list1.getLength() + 1].*
		END FOREACH
		CALL m_sel_list1.deleteElement( m_sel_list1.getLength() )
		LET m_list1_date = l_updated_date
		RETURN TRUE
	END IF

	LET l_json = mob_ws_lib.ws_call("getList1", m_user)
	IF l_json IS NULL THEN RETURN FALSE END IF

	CALL util.JSON.parse(l_json, m_sel_list1 )
	DELETE FROM sel_list1
	FOR x = 1 TO m_sel_list1.getLength()
		INSERT INTO sel_list1 VALUES( m_sel_list1[x].* )
	END FOR
	LET m_list1_date = l_now
	DELETE FROM table_updated WHERE table_name = "sel_list1"
	INSERT INTO table_updated VALUES("sel_list1",l_now )
	MESSAGE m_sel_list1.getLength()," from server"
	DISPLAY m_sel_list1.getLength()," from server"
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_dets1(l_key STRING) RETURNS BOOLEAN
	DEFINE l_json STRING
	DEFINE l_now DATETIME YEAR TO SECOND

	INITIALIZE m_dets1.* TO NULL
	SELECT * INTO m_dets1.* FROM dets1 WHERE customer_code = l_key

	LET l_now = CURRENT
	IF m_dets1.updated_date IS NOT NULL
	AND m_dets1.updated_date > ( l_now - 1 UNITS DAY ) THEN
		RETURN TRUE -- got data from DB
	ELSE
		IF NOT check_network() THEN
			CALL gl_lib.gl_winMessage("Error","Not connected and Data not available locally","exclamation")
			RETURN FALSE
		END IF
	END IF

	LET l_json = mob_ws_lib.ws_call("getDets1", l_key )
	IF l_json IS NULL THEN RETURN FALSE END IF

	CALL util.JSON.parse(l_json, m_dets1)
	LET m_dets1.updated_date = l_now
	DELETE FROM dets1 WHERE customer_code = l_key
	INSERT INTO dets1 VALUES(m_dets1.*)
	RETURN TRUE
END FUNCTION