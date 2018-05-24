
IMPORT util
IMPORT os
IMPORT com
IMPORT security

IMPORT FGL gl_lib

PUBLIC DEFINE m_ret RECORD
		ver SMALLINT,
		stat SMALLINT,
		type STRING,
		reply STRING
	END RECORD

PUBLIC DEFINE m_sc_rec RECORD
		api_param RECORD
			jobid STRING,
			custid STRING,
			vrn STRING
		END RECORD,
		sent RECORD
			ts DATETIME YEAR TO SECOND,
			send_size STRING,
			files DYNAMIC ARRAY OF RECORD
				filename STRING,
				size STRING
			END RECORD
		END RECORD,
		reply RECORD
			link STRING,
			jobid STRING,
			msg STRING,
			err STRING
		END RECORD
	END RECORD

--------------------------------------------------------------------------------
-- Service Certainly
--------------------------------------------------------------------------------
FUNCTION ws_putMedia_sc(l_files) RETURNS STRING
	DEFINE l_files DYNAMIC ARRAY OF RECORD
		filename STRING,
		size STRING,
		vid BOOLEAN
	END RECORD
	DEFINE x, l_errors SMALLINT
	DEFINE l_vids, l_imgs BOOLEAN

	LET l_vids = FALSE
	FOR x = 1 TO l_files.getLength()
		IF NOT l_files[x].vid THEN LET l_imgs = TRUE END IF
		IF l_files[x].vid THEN LET l_vids = TRUE END IF
	END FOR

	LET l_errors = 0
	IF l_imgs THEN
		IF NOT doRestServiceCertainty( FALSE, m_sc_rec.api_param.jobid, m_sc_rec.api_param.custid, m_sc_rec.api_param.vrn, l_files ) THEN
			LET l_errors = l_errors + 1
		END IF
	END IF
	IF l_vids THEN
		IF NOT doRestServiceCertainty( TRUE, m_sc_rec.api_param.jobid, m_sc_rec.api_param.custid, m_sc_rec.api_param.vrn, l_files ) THEN
			LET l_errors = l_errors + 1
		END IF
	END IF
	RETURN IIF(l_errors=0, %"All Media Sent", SFMT(%"ERR: %1 Failed to send", l_errors))
END FUNCTION
--------------------------------------------------------------------------------
-- Service Certainty 
PRIVATE FUNCTION doRestServiceCertainty(l_vids, l_jobid, l_custid, l_vrn, l_files) RETURNS BOOLEAN
	DEFINE l_vids BOOLEAN
	DEFINE l_jobid STRING, l_custid STRING, l_vrn STRING
	DEFINE l_files DYNAMIC ARRAY OF RECORD
		filename STRING,
		size STRING,
		vid BOOLEAN
	END RECORD
	DEFINE l_url, l_user, l_pass STRING
	DEFINE l_req com.HttpRequest
	DEFINE l_resp com.HttpResponse
	DEFINE l_stat, x SMALLINT
	DEFINE l_data, l_textReply, l_json STRING
	DEFINE l_jo, l_jo_ref util.JSONObject
	DEFINE l_ja_imgs util.JSONArray
	DEFINE l_ext STRING
	DEFINE l_ret RECORD
		link STRING,
		references RECORD
			jobId STRING
		END RECORD,
		success BOOLEAN,
		message STRING
	END RECORD

	IF l_vids THEN
		LET l_url = fgl_getResource("mob_bms.ws_sc_url_vid")
	ELSE
		LET l_url = fgl_getResource("mob_bms.ws_sc_url_img")
	END IF
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
	LET m_sc_rec.sent.ts = CURRENT
	FOR x = 1 TO l_files.getLength()
		IF ( l_vids AND l_files[x].vid )
		OR ( NOT l_vids AND NOT l_files[x].vid ) THEN
			LET m_sc_rec.sent.files[x].filename = l_files[x].filename
			LET m_sc_rec.sent.files[x].size = l_files[x].size
			TRY
				LET l_ext = os.path.extension(l_files[x].filename)
				IF l_files[x].vid THEN
					LET l_data = "data:video/"||l_ext||";base64,"||security.Base64.LoadBinary( l_files[x].filename )
				ELSE
					LET l_data = "data:image/"||l_ext||";base64,"||security.Base64.LoadBinary( l_files[x].filename )
				END IF
			CATCH
				LET m_ret.reply = SFMT("WS Media Processing failed!\n%1-%2",STATUS,l_files[x].filename )
				RETURN FALSE
			END TRY
			CALL l_ja_imgs.put(x, l_data)
		END IF
	END FOR
	IF l_vids THEN
		CALL l_jo.put("videos", l_ja_imgs)
	ELSE
		CALL l_jo.put("images", l_ja_imgs)
	END IF

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
	LET m_sc_rec.sent.send_size = l_jo.toString().getLength()
	LET m_ret.stat = l_stat
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_logIt("Error:"||NVL(m_ret.reply,"NULL"))
		CALL gl_lib.gl_winMessage("WS Error", m_ret.reply,"exclamation")
		LET m_sc_rec.reply.err = m_ret.reply
		LET m_sc_rec.reply.msg = NVL(l_ret.message,"NULL")
		IF ws_sendData( util.JSON.stringify(m_sc_rec) ) IS NULL THEN
		END IF
		RETURN FALSE
	END IF
	LET m_ret.reply = l_ret.link
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))

	LET m_sc_rec.reply.jobid = NVL(l_ret.references.jobId,"NULL")
	LET m_sc_rec.reply.link = NVL(l_ret.link,"NULL")
	LET m_sc_rec.reply.msg = NVL(l_ret.message,l_ret.success)
	IF ws_sendData( util.JSON.stringify(m_sc_rec) ) IS NULL THEN
-- failed to send reply to our server!
		CALL gl_lib.gl_logIt("Failed to send reply to our server!")
	END IF
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
-- Return JSON from a string that might not start with JSON
-- Should return a string that starts with { and ends with } or returns NULL
PRIVATE FUNCTION findJson( l_txt STRING ) RETURNS STRING
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