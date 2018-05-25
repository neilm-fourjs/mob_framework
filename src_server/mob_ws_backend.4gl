
-- Mobile Web Server Demo

IMPORT com
IMPORT util
IMPORT os

IMPORT FGL gl_lib
IMPORT FGL gl_lib_restful
IMPORT FGL lib_secure
IMPORT FGL mob_db_backend
IMPORT FGL mob_app_backend

&include "mob_ws_lib.inc"

DEFINE m_ret t_ws_reply_rec
GLOBALS
	DEFINE g_user STRING
END GLOBALS

MAIN
	DEFINE l_ret INTEGER
	DEFINE l_req com.HTTPServiceRequest
	DEFINE l_str STRING
	DEFINE l_quit BOOLEAN

	DEFER INTERRUPT

	CALL STARTLOG( base.Application.getProgramName()||".err" )

	LET m_ret.ver = WS_VER

	CALL mob_db_backend.db_connect()

	LET l_str = mob_app_backend.init_app_backend()

	CALL gl_lib.gl_logIt(SFMT(%"Starting server, FGLAPPSERVER=%1 ...",fgl_getEnv("FGLAPPSERVER")))
	#
	# Starts the server on the port number specified by the FGLAPPSERVER environment variable
	# (EX: FGLAPPSERVER=8090)
	# 
	TRY
		CALL com.WebServiceEngine.Start()
		CALL gl_lib.gl_logIt(%"The server is listening.")
	CATCH
		CALL gl_lib.gl_logIt( SFMT("%1:%2",STATUS,ERR_GET(STATUS)) )
		EXIT PROGRAM
	END TRY

	WHILE NOT l_quit
		TRY
			# create the server
			LET l_req = com.WebServiceEngine.getHTTPServiceRequest(-1)
			CALL gl_lib_restful.gl_getReqInfo(l_req)

			CALL gl_lib.gl_logIt(SFMT(%"Processing request, Method:%1 Path:%2 Format:%3", gl_lib_restful.m_reqInfo.method, gl_lib_restful.m_reqInfo.path, gl_lib_restful.m_reqInfo.outformat))
			-- parse the url, retrieve the operation and the operand
			CASE gl_lib_restful.m_reqInfo.method
				WHEN "GET"
					CASE
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("checkToken") 
							IF checkToken("checkToken") THEN
							END IF
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getToken") 
							CALL getToken()
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getList1") 
							CALL getList1()
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getList2") 
							CALL getList2()
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getDets1") 
							CALL getDets1()
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getDets2") 
							CALL getDets2()
						OTHERWISE
							CALL setReply(201,%"ERR",SFMT(%"GET Operation '%1' not found",gl_lib_restful.m_reqInfo.path))
					END CASE
					LET l_str = util.JSON.stringify(m_ret)
				WHEN "POST"
					CASE
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("putPhoto") 
							CALL getMedia(l_req, FALSE)
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("putVideo") 
							CALL getMedia(l_req, TRUE)
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("sendData")
							CALL getData(l_req)
						OTHERWISE
							CALL setReply(201,%"ERR",SFMT(%"POST Operation '%1' not found",gl_lib_restful.m_reqInfo.path))
					END CASE
					LET l_str = util.JSON.stringify(m_ret)
				OTHERWISE
					CALL gl_lib_restful.gl_setError("Unknown request:\n"||m_reqInfo.path||"\n"||m_reqInfo.method)
					LET gl_lib_restful.m_err.code = -3
					LET gl_lib_restful.m_err.desc = SFMT(%"Method '%' not supported",gl_lib_restful.m_reqInfo.method)
					LET l_str = util.JSON.stringify(m_err)
			END CASE
			-- send back the response.
			CALL l_req.setResponseHeader("Content-Type","application/json")
			CALL gl_lib.gl_logIt(%"Replying:"||NVL(l_str,"NULL"))
			CALL l_req.sendTextResponse(200, "Ok!", l_str)
			IF int_flag != 0 THEN LET int_flag=0 EXIT WHILE END IF
		CATCH
			LET l_ret = STATUS
			CASE l_ret
				WHEN -15565
					CALL gl_lib.gl_logIt(%"Disconnected from application server.")
					EXIT WHILE
				OTHERWISE
					CALL gl_lib.gl_logIt(%"[ERROR] "||NVL(l_ret,"NULL")||" : "||ERR_GET(l_ret))
					EXIT WHILE
				END CASE
		END TRY
	END WHILE
	CALL gl_lib.gl_logIt(%"Service Exited.")
END MAIN
--------------------------------------------------------------------------------
FUNCTION setReply(l_stat SMALLINT, l_typ STRING, l_msg STRING)
	LET m_ret.stat = l_stat
	LET m_ret.type = l_typ
	LET m_ret.reply = l_msg
	CALL gl_lib.gl_logIt(SFMT(%"setReply, Stat:%1 Type:%2 Reply:%3", l_stat, l_typ, l_msg))
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getToken()
	DEFINE l_xml, l_user, l_pass STRING
	DEFINE l_token STRING

	LET l_xml = gl_lib_restful.gl_getParameterValueByKey("xml")
	IF l_xml.subString(1,4) = "ERR:" THEN
		CALL setReply(203,%"ERR",l_xml)
		RETURN
	END IF
	IF l_xml.getCharAt(1) != "<" THEN
		CALL setReply(203,%"ERR",SFMT(%"XML looks invalid '%1'!",l_xml))
		RETURN
	END IF

	CALL lib_secure.glsec_decryptCreds( l_xml ) RETURNING l_user, l_pass

	LET l_token = mob_db_backend.db_check_user( l_user, l_pass )
	IF l_token IS NULL THEN
		CALL setReply(202,%"ERR",%"Login Invalid!")
		RETURN
	END IF

	CALL setReply(200,%"OK",l_token)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION checkToken(l_func STRING) RETURNS BOOLEAN
	DEFINE l_token, l_res STRING

	LET l_token = gl_lib_restful.gl_getParameterValueByKey("token")
	IF l_token.subString(1,4) = "ERR:" THEN
		CALL setReply(201,%"ERR",l_token)
		RETURN FALSE
	END  IF

	LET l_res = mob_db_backend.db_check_token( l_token )
	IF l_res.subString(1,4) = "ERR:" THEN
		CALL setReply(201,%"ERR",l_res)
		RETURN FALSE
	END IF
	LET g_user = l_res
	CALL mob_db_backend.db_log_access(g_user,SFMT("%1?%2",gl_lib_restful.m_reqInfo.path,gl_lib_restful.m_reqInfo.query))
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getList1()
	DEFINE l_data STRING

	IF NOT checkToken("getList1") THEN RETURN END IF

	CALL gl_lib.gl_logIt(%"Return customer list for user:"||NVL(g_user,"NULL"))

	LET l_data = mob_db_backend.db_get_custs()
	CALL gl_lib.gl_logIt(SFMT(%"Data size is %1", l_data.getLength()))

	CALL setReply(200,%"OK",l_data)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getList2()
	DEFINE l_data, l_key STRING

	IF NOT checkToken("getList2") THEN RETURN END IF

	LET l_key = gl_lib_restful.gl_getParameterValueByKey("key")
	IF l_key.subString(1,4) = "ERR:" THEN
		CALL setReply(201,%"ERR",l_key)
		RETURN
	END  IF

	CALL gl_lib.gl_logIt(%"Return order list for customer:"||NVL(l_key,"NULL"))

	LET l_data = mob_db_backend.db_get_orders(l_key)

	CALL setReply(200,%"OK",l_data)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getDets1()
	DEFINE l_data, l_key STRING

	IF NOT checkToken("getDets1") THEN RETURN END IF

	LET l_key = gl_lib_restful.gl_getParameterValueByKey("key")
	IF l_key.subString(1,4) = "ERR:" THEN
		CALL setReply(201,%"ERR",l_key)
		RETURN
	END  IF

	CALL gl_lib.gl_logIt(%"Return details for customer:"||NVL(l_key,"NULL"))

	LET l_data = mob_db_backend.db_get_custDets(l_key)

	CALL setReply(200,%"OK",l_data)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getDets2()
	DEFINE l_data, l_key STRING

	IF NOT checkToken("getDets2") THEN RETURN END IF

	LET l_key = gl_lib_restful.gl_getParameterValueByKey("key")
	IF l_key.subString(1,4) = "ERR:" THEN
		CALL setReply(202,%"ERR",l_key)
		RETURN
	END IF

	CALL gl_lib.gl_logIt(%"Return details for order:"||NVL(l_key,"NULL"))

	LET l_data = mob_db_backend.db_get_orderDets(l_key)

	CALL setReply(200,%"OK",l_data)
END FUNCTION
--------------------------------------------------------------------------------
-- getMedia - handle a photo/video being received.
FUNCTION getMedia(l_req com.HTTPServiceRequest, l_vid BOOLEAN)
	DEFINE l_media_file, l_ret, l_imgid STRING

	IF NOT checkToken("getMedia") THEN RETURN END IF

	LET l_imgid = gl_lib_restful.gl_getParameterValueByKey("imgid")
	IF l_imgid.subString(1,4) = "ERR:" THEN
		CALL setReply(202,%"ERR",l_imgid)
		RETURN
	END IF

	CALL gl_lib.gl_logIt(%"Getting "||IIF(l_vid,"Video","Photo")||" ...")
	TRY
		LET l_media_file = l_req.readFileRequest()
	CATCH
		CALL setReply(200,%"ERR",SFMT(%"ERR: Media receive Failed: %1:%2",STATUS,ERR_GET(STATUS)))
		RETURN
	END TRY

	CALL gl_lib.gl_logIt(%"Got :"||IIF(l_vid,"Video","Photo")||NVL(l_media_file,"NULL"))
	IF os.Path.exists( l_media_file ) THEN
		CALL setReply(200,%"OK", SFMT(%"ERR: Media File %1 received",l_media_file))
	ELSE
		CALL setReply(200,%"OK",%"ERR: Media File Doesn't Exists!")
		RETURN
	END IF

	LET l_ret = mob_app_backend.process_media(l_media_file, l_vid, l_imgid)
	IF l_ret.subString(1,4) = "ERR:" THEN
		CALL setReply(200,%"OK", l_ret)
	END IF

END FUNCTION
--------------------------------------------------------------------------------
-- simple fetch data from the server.
FUNCTION getData(l_req com.HTTPServiceRequest)
	DEFINE l_str STRING

	IF NOT checkToken("getData") THEN RETURN END IF

	CALL gl_lib.gl_logIt(%"Getting Text Data ...")
	TRY
		LET l_str = l_req.readTextRequest()
	CATCH
		CALL setReply(200,%"ERR",%"Data receive Failed!")
		RETURN
	END TRY

	CALL mob_db_backend.db_log_data(g_user,l_str)

	CALL gl_lib.gl_logIt(%"Data:"||NVL(l_str,"NULL"))
	CALL setReply(200,%"OK",%"Data received")
END FUNCTION
--------------------------------------------------------------------------------