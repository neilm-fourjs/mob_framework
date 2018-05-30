-- Core Mobile Library Code

IMPORT util
IMPORT os

IMPORT FGL gl_lib
IMPORT FGL gl_resources
IMPORT FGL lib_secure
IMPORT FGL mob_app_lib
IMPORT FGL mob_ws_lib
IMPORT FGL mob_ws_lib_sc

&include "mob_ws_lib.inc"

CONSTANT DB_VER = 1

DEFINE m_init_db BOOLEAN
PUBLIC DEFINE m_connected BOOLEAN
PUBLIC DEFINE m_user STRING
PUBLIC DEFINE m_cli_ver STRING

FUNCTION init_mob()
	DEFINE l_dbname STRING

	CALL gl_initResources()

	LET m_cli_ver = ui.Interface.getFrontEndVersion()
	LET gl_lib.m_logName = gl_resources.gl_getResource("logname",base.Application.getProgramName()||"-"||m_cli_ver||".log")

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
	
	CALL ui.form.setDefaultInitializer("init_form")

	CALL gl_lib.gl_logIt("*** Started ***")
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION init_form(l_f ui.Form) 
	DEFINE l_titl, l_ver STRING

	LET l_titl = l_f.getNode().getAttribute("text")
	CALL l_f.getNode().setAttribute("text",l_titl||" "||m_cli_ver)
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
		DROP TABLE table_updated
	CATCH
	END TRY
	CREATE TABLE table_updated (
		table_name CHAR(20),
		updated_date DATETIME YEAR TO SECOND
	)

	CALL mob_app_lib.init_app_db()

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION view_log()
	DEFINE l_log, l_file STRING
	DEFINE c base.channel
	OPEN WINDOW view_log WITH FORM "view_log"

	LET l_file = os.path.join(gl_lib.gl_getLogDir(),gl_lib.gl_getLogName()||".log")
	LET l_log = "File:",l_file||"\n"
	LET c = base.Channel.create()
	TRY
		CALL c.openFile(l_file,"r")
		WHILE NOT c.isEof()
			LET l_log = l_log.append( c.readLine()||"\n" )
		END WHILE
		CALL c.close()
	CATCH
		LET l_log = SFMT(%"Failed to open %1",l_file)
	END TRY

	DISPLAY BY NAME l_log

	MENU
		ON ACTION delete
			IF NOT os.path.delete( l_file ) THEN
				CALL fgl_winMessage("Error","Failed to delete the log file!","exclamation")
			ELSE
				EXIT PROGRAM
			END IF
		ON ACTION back EXIT MENU
		ON ACTION close EXIT MENU
	END MENU

	CLOSE WINDOW view_log
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION login() RETURNS BOOLEAN
	DEFINE l_user, l_pass STRING
	DEFINE l_token, l_salt, l_pass_hash, l_xml_creds STRING
	DEFINE l_now, l_token_date DATETIME YEAR TO SECOND 

	OPEN WINDOW mob_login WITH FORM "mob_login"

	DISPLAY mob_app_lib.m_apptitle TO f_apptitle
	DISPLAY mob_app_lib.m_welcome TO f_welcome
	DISPLAY mob_app_lib.m_logo TO f_logo
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
		IF NOT check_network() THEN
			CALL gl_lib.gl_winMessage("Error","Invalid Login, a network connection required\nConnect to network and try again","exclamation")
			EXIT PROGRAM
		END IF
		LET l_xml_creds = lib_secure.glsec_encryptCreds(l_user, l_pass)
		IF l_xml_creds IS NULL THEN
			CALL gl_lib.gl_winMessage("Error","Error in security routine\nTry again later","exclamation")
			EXIT PROGRAM
		END IF
		LET l_token = ws_getSecurityToken( l_xml_creds ) 
		IF l_token IS NULL THEN
			CALL gl_lib.gl_winMessage("Error","Unable to get security token\nTry again later","exclamation")
			EXIT PROGRAM
		END IF
		IF l_salt IS NULL THEN
			LET l_salt = lib_secure.glsec_genSalt( NULL )
			LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
			INSERT INTO users VALUES(l_user, l_pass_hash, l_salt, l_token, l_now )
		ELSE
			UPDATE users SET ( token, token_date ) = ( l_token, l_now )
				WHERE username = l_user
		END IF
		LET l_token_date = l_now
		EXIT WHILE
	END WHILE
	LET m_user = l_user
	LET mob_ws_lib.m_security_token = l_token
	CALL gl_lib.gl_logIt(SFMT("Security Token: %1 From:%2",NVL(l_token.trim(),"NULL"),l_token_date))

	CLOSE WINDOW mob_login
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
FUNCTION check_token()
	DEFINE l_ret STRING

	IF check_network() THEN
		LET l_ret = mob_ws_lib.ws_checkToken()
		IF l_ret IS NOT NULL THEN
			CALL gl_lib.gl_winMessage("Info",l_ret,"information")
		ELSE
-- token invalid - delete the user from the local db!
			DELETE FROM users WHERE username = m_user
			IF NOT login() THEN -- force re-login
				EXIT PROGRAM
			END IF
		END IF
	ELSE
		CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
	END IF

END FUNCTION
--------------------------------------------------------------------------------
-- List Media for the JobId
FUNCTION list_media1()
	DEFINE l_imgs DYNAMIC ARRAY OF STRING
	DEFINE l_arr DYNAMIC ARRAY OF RECORD
		img STRING,
		tn STRING
	END RECORD
	DEFINE l_json STRING
	DEFINE l_jobid, l_name, l_path STRING
	DEFINE x SMALLINT

	OPEN WINDOW list_media WITH FORM "list_media"

	LET l_jobid = mob_app_lib.m_param.jobid

	LET l_json = mob_ws_lib.ws_getMediaList(l_jobid)
	IF l_json IS NULL THEN
		CALL fgl_winMessage("Error",l_json,"exclamation")
		CLOSE WINDOW list_media
		RETURN
	END IF

	CALL util.JSON.parse( l_json, l_imgs )

	FOR x = 1 TO l_imgs.getLength()
		LET l_path = os.path.dirname(l_imgs[x])
		LET l_name = os.path.rootName(os.Path.basename(l_imgs[x]))
		LET l_arr[x].img = l_name
		LET l_arr[x].tn = l_path||"/tn_"||l_name||".gif"
		--DISPLAY "tn:",l_arr[x].tn
	END FOR

	DISPLAY ARRAY l_arr TO arr.* ATTRIBUTES( ACCEPT=FALSE )
		BEFORE ROW 
			DISPLAY l_arr[ arr_curr() ].tn TO f_img
		ON ACTION select
			CALL ui.Interface.frontCall("standard","launchURL",[ l_imgs[ arr_curr() ] ],[l_json])
	END DISPLAY

	CLOSE WINDOW list_media
END FUNCTION
--------------------------------------------------------------------------------
-- Take / Choose a Photo and send to the server
FUNCTION send_media()
	DEFINE l_media_file, l_local_file, l_ret STRING
	DEFINE l_files DYNAMIC ARRAY OF RECORD
		filename STRING,
		size STRING,
		vid BOOLEAN
	END RECORD
	DEFINE l_param t_param_rec
	DEFINE x SMALLINT

	LET l_param.* = mob_app_lib.m_param.*

	OPEN WINDOW show_photo WITH FORM "show_media"

	DISPLAY "Select media to send." TO status
	LET int_flag = FALSE
	DIALOG ATTRIBUTES(UNBUFFERED)
		INPUT BY NAME l_param.* ATTRIBUTES(WITHOUT DEFAULTS)
		END INPUT
		DISPLAY ARRAY l_files TO arr.*
		END DISPLAY
		ON ACTION take_photo
			CALL ui.Interface.frontCall("mobile","takePhoto",[],[l_media_file])
			LET l_local_file = process_file(l_media_file, FALSE)
			IF l_local_file IS NOT NULL THEN
				LET l_files[ l_files.getLength() + 1 ].filename = l_local_file
				LET l_files[ l_files.getLength() ].size = os.path.size(l_local_file)
				LET l_files[ l_files.getLength() ].vid = FALSE
				CALL DIALOG.setActionActive("send",TRUE)
				CALL DIALOG.setActionActive("send_sc",TRUE)
			END IF

		ON ACTION choose_photo
			CALL ui.Interface.frontCall("mobile","choosePhoto",[],[l_media_file])
			LET l_local_file = process_file(l_media_file, FALSE)
			IF l_local_file IS NOT NULL THEN
				LET l_files[ l_files.getLength() + 1 ].filename = l_local_file
				LET l_files[ l_files.getLength() ].size = os.path.size(l_local_file)
				LET l_files[ l_files.getLength() ].vid = FALSE
				CALL DIALOG.setActionActive("send",TRUE)
				CALL DIALOG.setActionActive("send_sc",TRUE)
			END IF

		ON ACTION take_video
			CALL ui.Interface.frontCall("mobile","takeVideo",[],[l_media_file])
			LET l_local_file = process_file(l_media_file, TRUE)
			IF l_local_file IS NOT NULL THEN
				LET l_files[ l_files.getLength() + 1 ].filename = l_local_file
				LET l_files[ l_files.getLength() ].size = os.path.size(l_local_file)
				LET l_files[ l_files.getLength() ].vid = TRUE
				CALL DIALOG.setActionActive("send",TRUE)
				CALL DIALOG.setActionActive("send_sc",TRUE)
			END IF

		ON ACTION choose_video
			CALL ui.Interface.frontCall("mobile","chooseVideo",[],[l_media_file])
			LET l_local_file = process_file(l_media_file, TRUE)
			IF l_local_file IS NOT NULL THEN
				LET l_files[ l_files.getLength() + 1 ].filename = l_local_file
				LET l_files[ l_files.getLength() ].size = os.path.size(l_local_file)
				LET l_files[ l_files.getLength() ].vid = TRUE
				CALL DIALOG.setActionActive("send",TRUE)
				CALL DIALOG.setActionActive("send_sc",TRUE)
			END IF

		ON ACTION send
			IF check_network() THEN
				DISPLAY %"Sending, please wait ..." TO status
				LET l_ret =  mob_ws_lib.ws_putMedia( l_files, l_param.* )
				IF l_ret.subString(1,4) = "ERR:" THEN
					DISPLAY l_ret TO status
				ELSE
					CALL gl_lib.gl_winMessage("Info",l_ret,"information")
					CALL l_files.clear()
					CALL DIALOG.setActionActive("send",FALSE)
					CALL DIALOG.setActionActive("send_sc",FALSE)
					DISPLAY %"Files Send, choose more?" TO status
				END IF
			ELSE
				CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
			END IF

		ON ACTION send_sc
			IF check_network() THEN
				DISPLAY %"Sending, please wait ..." TO status
				CALL ui.interface.refresh()
				LET l_ret =  mob_ws_lib_sc.ws_putMedia_sc( l_files, l_param.*)
				IF l_ret.subString(1,4) = "ERR:" THEN
					DISPLAY l_ret TO status
				ELSE
					CALL gl_lib.gl_winMessage("Info",l_ret,"information")
					CALL l_files.clear()
					CALL DIALOG.setActionActive("send",FALSE)
					CALL DIALOG.setActionActive("send_sc",FALSE)
					DISPLAY "Files Send, choose more?" TO status
				END IF
			ELSE
				CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
			END IF

		ON ACTION back EXIT DIALOG
		BEFORE DIALOG
			CALL DIALOG.setActionActive("send",FALSE)
			CALL DIALOG.setActionActive("send_sc",FALSE)
			IF gl_resources.gl_getResource("mob_ws_sc_user",NULL) IS NOT NULL THEN
				CALL DIALOG.setActionHidden("send_sc",FALSE)
			END IF
	END DIALOG
	FOR x = 1 TO l_files.getLength()
		IF NOT os.path.delete( l_files[x].filename ) THEN
			CALL gl_lib.gl_logIt(%"Failed to delete local file!")
		END IF
	END FOR
	LET int_flag = FALSE
	CLOSE WINDOW show_photo
END FUNCTION
--------------------------------------------------------------------------------
-- send some data to the server
FUNCTION process_file(l_media_file STRING, l_vid BOOLEAN) RETURNS STRING
	DEFINE l_local_file STRING
	IF l_media_file IS NULL THEN RETURN NULL END IF

	CALL gl_lib.gl_logIt(SFMT(%"Processing %1 ...",l_media_file))

	DISPLAY "Processing file, please wait ..." TO status
	CALL ui.interface.refresh()

	LET l_local_file = util.Datetime.format( CURRENT, "%Y%m%d_%H%M%S"||IIF(l_vid,".mp4",".jpg") )
	TRY
		CALL fgl_getfile(l_media_file, l_local_file)
	CATCH
		CALL gl_lib.gl_winMessage("Error",ERR_GET( STATUS ),"exclamation")
	END TRY

	DISPLAY "Processing done, ready to send." TO status
	CALL ui.interface.refresh()

	IF NOT os.path.exists( l_local_file ) THEN
		ERROR l_local_file||" Missing!"
		CALL gl_lib.gl_logIt(SFMT(%"%1 Missing!",l_local_file))
		RETURN NULL
	ELSE
		CALL gl_lib.gl_logIt(SFMT(%"Processed to %1 completed.",l_local_file))
	END IF
	RETURN l_local_file
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

FUNCTION list_media2()
	DEFINE l_imgs DYNAMIC ARRAY OF STRING
	DEFINE l_arr DYNAMIC ARRAY OF RECORD
		img STRING,
		tn STRING
	END RECORD
	DEFINE l_name, l_path STRING
	DEFINE i INT

	OPEN WINDOW list_media WITH FORM "list_media"

	LET i=0
	LET l_imgs[i:=i+1] = "https://i.imgur.com/5qAiokY.png"
	LET l_imgs[i:=i+1] = "https://i.imgur.com/p7Q7Pz5.png"
--"https://i.imgur.com/xdmAnos.jpg" --NJM My big image
	LET l_imgs[i:=i+1] = "https://i.imgur.com/IrEsnaK.gif"
-- https://uk3.generocloud.net/ws_mob_media/B499E473-4570-4EC1-A192-49F462720FDB/tn_20180530_101754.gif"


	FOR i = 1 TO l_imgs.getLength()
		LET l_arr[i].img = l_imgs[i]
		LET l_path = os.path.dirname(l_imgs[i])
		LET l_name = os.path.rootName(os.Path.basename(l_imgs[i]))
		LET l_arr[i].tn = l_path||"/"||l_name||".jpg"
		DISPLAY "tn:",l_arr[i].tn
	END FOR

	DISPLAY ARRAY l_arr TO arr.* ATTRIBUTES( ACCEPT=FALSE )
		BEFORE ROW
			DISPLAY "Img:", l_arr[ arr_curr() ].img
			DISPLAY l_arr[ arr_curr() ].tn TO f_img
		ON ACTION select
			CALL ui.Interface.frontCall("standard","launchURL",[ l_arr[ arr_curr() ].img ],[l_path])
	END DISPLAY

	CLOSE WINDOW list_media

END FUNCTION