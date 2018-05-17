
-- Mobile Web Service Functions

IMPORT util
IMPORT com
IMPORT security

IMPORT FGL gl_lib

CONSTANT WS_VER = 1

PUBLIC DEFINE m_security_token STRING
PUBLIC DEFINE m_ret RECORD
		ver SMALLINT,
		stat SMALLINT,
		type STRING,
		reply STRING
	END RECORD
--------------------------------------------------------------------------------
FUNCTION ws_getSecurityToken( l_xml_creds STRING )
-- call the restful service to get the security token
	IF NOT doRestRequest( SFMT("getToken?xml=%1",l_xml_creds)) THEN
		RETURN NULL
	END IF

	IF m_ret.ver != WS_VER THEN
		CALL gl_lib.gl_winMessage("Error",SFMT("Webversion Version Mismatch\nGot %1, expected %2",m_ret.ver,WS_VER),"exclamation")
	END IF

	LET m_security_token = m_ret.reply
	RETURN m_security_token
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION ws_call(l_func STRING, l_key STRING) RETURNS STRING
	IF NOT doRestRequest(SFMT("%1?token=%2&key=%3",l_func,m_security_token,l_key)) THEN
		RETURN NULL
	END IF
	RETURN m_ret.reply
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION ws_putMedia(l_media_file STRING, l_vid BOOLEAN) RETURNS STRING
	DEFINE l_call STRING
	LET l_call = IIF(l_vid,"putVideo","putPhoto")
	IF NOT doRestRequestMedia(SFMT("%1?token=%2", l_call, m_security_token),l_media_file, l_vid) THEN
		RETURN NULL
	END IF
	RETURN IIF(l_vid,"Video Sent","Photo Sent")
END FUNCTION
--------------------------------------------------------------------------------
-- Send some json data back to server
--
-- @params l_data String JSON data
FUNCTION ws_sendData(l_data STRING) RETURNS STRING
	IF NOT doRestRequestData(SFMT("sendData?token=%1",m_security_token),l_data) THEN
		RETURN NULL
	END IF
	RETURN "Data Sent"
END FUNCTION

-- Private functions

--------------------------------------------------------------------------------
-- Do the web service REST call to check for a new GDC
PRIVATE FUNCTION doRestRequest(l_param STRING) RETURNS BOOLEAN
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))

	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("GET")
		CALL l_req.setHeader("Content-Type", "application/json")
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.doRequest()
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
		CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
		LET m_ret.reply = SFMT("WS Call #1 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
		LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Do the web service REST call to POST a Photo
PRIVATE FUNCTION doRestRequestMedia(l_param STRING, l_media_file STRING, l_vid BOOLEAN) RETURNS BOOLEAN
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))

	DISPLAY "Media File:",l_media_file
	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("POST")
		IF l_vid THEN
			CALL l_req.setHeader("Content-Type", "video/mp4")
		ELSE
			CALL l_req.setHeader("Content-Type", "image/jpg")
		END IF
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
		CALL l_req.doFileRequest(l_media_file)
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
			CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
			LET m_ret.reply = SFMT("WS Call #2 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
			LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Do the web service REST call to POST some Data
PRIVATE FUNCTION doRestRequestData(l_param STRING, l_data STRING)
	DEFINE l_url STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mob_framework.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequestData URL:"||NVL(l_url,"NULL"))

	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("POST")
		CALL l_req.setHeader("Content-Type", "application/json")
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
		CALL l_req.doTextRequest(l_data)
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
		IF l_stat = 200 THEN
			CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
		ELSE
			LET m_ret.reply = SFMT("WS Call #3 Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
			LET m_ret.stat = l_stat
		END IF
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION

--------------------------------------------------------------------------------
-- Service Certainty 
PRIVATE FUNCTION doRestServiceCertainty(l_jobid STRING, l_custid STRING, l_vrn STRING, l_files DYNAMIC ARRAY OF STRING) RETURNS BOOLEAN
	DEFINE l_url, l_user, l_pass STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat, x SMALLINT
	DEFINE l_data, l_textReply, l_json STRING
	DEFINE l_jo, l_jo_ref util.JSONObject
	DEFINE l_ja_imgs util.JSONArray
	DEFINE l_ret RECORD
		link STRING,
		references RECORD
			jobId STRING
		END RECORD,
		success BOOLEAN,
		message STRING
	END RECORD

	LET l_url = fgl_getResource("mob_bms.ws_sc_url")
	LET l_user = fgl_getResource("mob_bms.ws_sc_user")
	LET l_pass = fgl_getResource("mob_bms.ws_sc_pass")

	CALL gl_lib.gl_logIt("doRestServiceCertainty URL:"||NVL(l_url,"NULL"))

	LET l_jo = util.JSONObject.create()
	CALL l_jo.put("username", l_user)
	CALL l_jo.put("password", l_pass)
	LET l_jo_ref = util.JSONObject.create()
	CALL l_jo_ref.put("jobId", l_jobid)
	CALL l_jo_ref.put("customerid", l_custid)
	CALL l_jo_ref.put("vrn", l_vrn)
	CALL l_jo.put("references", l_jo_ref)
	LET l_ja_imgs = util.JSONArray.create()
	FOR x = 1 TO l_files.getLength()
		TRY
			LET l_data = security.Base64.LoadBinary( l_files[x] )
		CATCH
			LET m_ret.reply = SFMT("WS Image processing failed!\n%1-%2",STATUS,l_files[x] )
			RETURN FALSE
		END TRY
		CALL l_ja_imgs.put(x, l_data)
	END FOR
	CALL l_jo.put("images", l_ja_imgs)

-- Do the POST
	TRY
		LET l_req = com.HttpRequest.Create(l_url)
		CALL l_req.setMethod("POST")
		CALL l_req.setHeader("Content-Type", "application/json")
		CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.doTextRequest( l_jo.toString() )
		LET l_resp = l_req.getResponse()
		LET l_stat = l_resp.getStatusCode()
    LET l_textReply = l_resp.getTextResponse()
		LET l_json = findJson(l_textReply)
    CASE l_stat
      WHEN 200
				IF l_json IS NOT NULL THEN
        	CALL util.JSON.parse( l_json, l_ret )
				END IF
      WHEN 400
				IF l_json IS NOT NULL THEN
        	CALL util.JSON.parse( l_json, l_ret )
				END IF
				CALL gl_lib.gl_logIt(SFMT(%"Error 400:%1",l_textReply))
      OTHERWISE
        LET m_ret.reply = SFMT("WS Call Failed!\n%1-%2",l_stat, l_resp.getStatusDescription())
    END CASE
	CATCH
		LET l_stat = STATUS
		LET m_ret.reply = ERR_GET( l_stat )
	END TRY
	LET m_ret.stat = l_stat
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_logIt("Error:"||NVL(m_ret.reply,"NULL"))
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	LET m_ret.reply = l_ret.link
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Return JSON from a string that might not start with JSON
-- Should return a string that starts with { and ends with } or returns NULL
FUNCTION findJson( l_txt STRING ) RETURNS STRING
	DEFINE l_json STRING
	DEFINE x,z SMALLINT
	LET x = l_txt.getIndexOf("{",1) -- look for start of JSON
	IF x > 0 THEN
		FOR z = l_txt.getLength() TO x STEP -1 -- work backwards to find the last close json tag
			IF l_txt.getCharAt(z) = "}" THEN
				LET l_json = l_txt.subString( x, z)
				EXIT FOR
			END IF
		END FOR
	END IF
	RETURN l_json
END FUNCTION