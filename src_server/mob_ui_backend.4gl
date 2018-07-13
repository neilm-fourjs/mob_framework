
IMPORT os
IMPORT util

IMPORT FGL gl_lib
IMPORT FGL mob_db_backend
IMPORT FGL mob_app_backend
IMPORT FGL fglgallery

SCHEMA njm_demo310

DEFINE m_al DYNAMIC ARRAY OF RECORD LIKE ws_log_access.*
DEFINE m_ml DYNAMIC ARRAY OF RECORD
		key INTEGER,
		user_name LIKE ws_media_details.username,
		type LIKE ws_media_details.type,
		filename LIKE ws_media_details.filename,
		id LIKE ws_media_details.id,
		timestamp LIKE ws_media_details.timestamp,
		img STRING
	END RECORD
DEFINE m_dl  DYNAMIC ARRAY OF RECORD
		key INTEGER,
		username LIKE ws_log_data.username,
		data STRING,
		timestamp LIKE ws_log_data.access_date
	END RECORD

MAIN
	DEFINE l_ret STRING
	CALL STARTLOG( base.Application.getProgramName()||".err" )

	CALL mob_db_backend.db_connect(TRUE)

--	RUN "env | sort > /tmp/"||base.Application.getProgramName()||".env"

	CALL gl_lib.gl_logIt(SFMT("FGLIMAGEPATH=%1",fgl_getEnv("FGLIMAGEPATH")))

	PREPARE pre_ml FROM "SELECT md_key, username, type, filename, id, timestamp FROM ws_media_details WHERE jobid LIKE ?"

	OPEN FORM f1 FROM "mob_ui_backend"
	DISPLAY FORM f1

	LET l_ret = mob_app_backend.init_app_backend()
	IF l_ret IS NOT NULL THEN
		CALL gl_winMessage("Error", l_ret, "exclamation")
		EXIT PROGRAM
	END IF

	CALL get_mediaLog("*")
	MENU %"Menu"
		ON ACTION users CALL users()
		ON ACTION accesslog CALL accessLog()
		ON ACTION medialog CALL mediaLog()
		ON ACTION gallery 
			WHILE showGallery()
				CALL get_mediaLog("*")
			END WHILE
		ON ACTION datalog CALL dataLog()
		ON ACTION quit EXIT MENU
	END MENU

END MAIN
--------------------------------------------------------------------------------
-- Manage mobile users in the database
-- 
-- @params 
-- @returns
FUNCTION users()
  
END FUNCTION
--------------------------------------------------------------------------------
-- Get the Access log Data
FUNCTION get_accessLog()
	CALL m_al.clear()
	DECLARE cur_al CURSOR FOR SELECT * FROM ws_log_access 
	FOREACH cur_al INTO m_al[ m_al.getLength() + 1 ].*
	END FOREACH
	CALL m_al.deleteElement( m_al.getLength() )
	MESSAGE SFMT(%"Got %1 AccessLog Records",m_al.getLength())
END FUNCTION
--------------------------------------------------------------------------------
-- View the Access log
-- 
-- @params 
-- @returns
FUNCTION accessLog()
	CALL get_accessLog()
	OPEN WINDOW al WITH FORM "accessLog"
	DISPLAY ARRAY m_al TO arr.*
		ON ACTION refresh CALL get_accessLog()
	END DISPLAY
	CLOSE WINDOW al
END FUNCTION
--------------------------------------------------------------------------------
-- Get the Data log data
FUNCTION get_dataLog()
	DEFINE l_dl_rec RECORD LIKE ws_log_data.*
	LOCATE l_dl_rec.data IN MEMORY
	DECLARE cur_dl CURSOR FOR SELECT * FROM ws_log_data
	CALL m_dl.clear()
	FOREACH cur_dl INTO l_dl_rec.*
		LET m_dl[ m_dl.getLength() + 1 ].username = l_dl_rec.username
		LET m_dl[ m_dl.getLength() ].data = l_dl_rec.data
		LET m_dl[ m_dl.getLength() ].timestamp = l_dl_rec.access_date
	END FOREACH
	MESSAGE SFMT(%"Got %1 DataLog Records",m_dl.getLength())
END FUNCTION
--------------------------------------------------------------------------------
-- View the Data log
-- {"api_param"
-- 123456789012
-- @params 
-- @returns
FUNCTION dataLog()

	DEFINE l_ret SMALLINT
	DEFINE l_url STRING
	DEFINE l_sc_rec RECORD
		api_param RECORD
			jobid STRING,
			custid STRING,
			vrn STRING
		END RECORD,
		sent RECORD
			ts DATETIME YEAR TO SECOND,
				files DYNAMIC ARRAY OF RECORD
				filename STRING,
				size STRING
			END RECORD
		END RECORD,
			reply RECORD
			link STRING,
			jobid STRING,
			msg STRING
		END RECORD
	END RECORD

	CALL get_dataLog()

	OPEN WINDOW dl WITH FORM "dataLog"
	
	DISPLAY ARRAY m_dl TO arr.*
		BEFORE ROW
			CALL DIALOG.setActionActive("select", FALSE)
			DISPLAY m_dl[ arr_curr() ].data TO f_data
			LET l_url = NULL
			IF m_dl[ arr_curr() ].data.subString(1,12) = "{\"api_param\"" THEN
				TRY
					CALL util.JSON.parse(m_dl[ arr_curr() ].data, l_sc_rec )
					LET l_url = l_sc_rec.reply.link
				CATCH
					ERROR "Invalid JSON!"
				END TRY
			END IF
			IF m_dl[ arr_curr() ].data.subString(1,8) = "https://" 
			OR m_dl[ arr_curr() ].data.subString(1,7) = "http://" THEN
				LET l_url = m_dl[ arr_curr() ].data
			END IF
			IF l_url iS NOT NULL THEN
				CALL DIALOG.setActionActive("select", TRUE)
			END IF
		ON ACTION select
				CALL ui.Interface.frontCall("standard", "launchURL", [ l_url ], l_ret)
		ON ACTION delete
			DELETE FROM ws_log_data WHERE ld_key = m_dl[arr_curr()].key
		ON ACTION refresh CALL get_dataLog()
	END DISPLAY

	CLOSE WINDOW dl
  
END FUNCTION
--------------------------------------------------------------------------------
-- Get the Media log Data
FUNCTION get_mediaLog(l_jobid LIKE ws_media_details.jobid )
	DEFINE l_thumb STRING
	DECLARE cur_ml CURSOR FOR pre_ml 
	CALL m_ml.clear()
	FOREACH cur_ml USING l_jobid INTO m_ml[ m_ml.getLength() + 1 ].*
--		LET m_ml[ m_ml.getLength() ].filepath = os.path.join(m_media_path, m_ml[ m_ml.getLength() ].filepath )
		LET l_thumb = os.path.join( 
					m_ml[ m_ml.getLength() ].id CLIPPED,
					getThumbFromImg( m_ml[ m_ml.getLength() ].filename))
		--LET l_thumb = os.path.join(m_ml[ m_ml.getLength() ].id CLIPPED,m_ml[ m_ml.getLength() ].filename CLIPPED)
		LET m_ml[ m_ml.getLength() ].img = os.path.join(m_media_path,l_thumb)
		IF os.path.exists( m_ml[ m_ml.getLength() ].img ) THEN
			DISPLAY m_ml[ m_ml.getLength() ].img||" Okay"
		ELSE
			DISPLAY m_ml[ m_ml.getLength() ].img||" Missing"
		END IF
		DISPLAY m_ml.getLength()," Img:",m_ml[ m_ml.getLength() ].img, " File:",m_ml[ m_ml.getLength() ].filename
	END FOREACH
	CALL m_ml.deleteElement( m_ml.getLength() )
	MESSAGE SFMT(%"Got %1 MediaLog Records",m_ml.getLength())
END FUNCTION
--------------------------------------------------------------------------------
-- View the Media log
--
-- @params
-- @returns
FUNCTION mediaLog()
	DEFINE l_jobid LIKE ws_media_details.jobid
	DEFINE l_ret, l_url, l_wc_url, l_file, l_filePath STRING
	DEFINE l_dnd ui.DragDrop

	OPEN WINDOW ml WITH FORM "mediaLog"
	LET l_jobid = "%"
	CALL get_mediaLog(l_jobid)

	DIALOG ATTRIBUTES(UNBUFFERED)
		INPUT l_jobid, l_wc_url FROM f_jobid, f_wc ATTRIBUTES(WITHOUT DEFAULTS)
			ON CHANGE f_jobid
				CALL get_mediaLog(l_jobid)
		END INPUT
		DISPLAY ARRAY m_ml TO arr.*
			BEFORE DISPLAY
				IF ui.Interface.getFrontEndName() = "GBC" THEN
					CALL DIALOG.setActionActive("open", FALSE)
				END IF

			BEFORE ROW 
				LET l_file = os.path.join( m_ml[arr_curr()].id CLIPPED,m_ml[arr_curr()].filename CLIPPED)
				LET l_filePath = os.path.join(m_media_path,l_file)
				LET l_url = mob_app_backend.getURL(l_file, os.path.mtime( l_filePath ))
				DISPLAY arr_curr(),":",m_ml[arr_curr()].type, " Filepath:",l_filePath
				DISPLAY "URL:",l_url
				IF m_ml[arr_curr()].type = "Photo" THEN
					CALL ui.Interface.frontCall("webcomponent", "call",
     				["formonly.f_wc", "setImage", l_url ], [l_ret] )
					CALL DIALOG.setActionActive("rotate_l",TRUE)
					CALL DIALOG.setActionActive("rotate_r",TRUE)
				END IF
				IF m_ml[arr_curr()].type = "Video" THEN
					CALL ui.Interface.frontCall("webcomponent", "call",
     				["formonly.f_wc", "setVideo", l_url ], [l_ret] )
					CALL DIALOG.setActionActive("rotate_l",FALSE)
					CALL DIALOG.setActionActive("rotate_r",FALSE)
				END IF
				DISPLAY "ret:",l_ret

			ON ACTION select
				CALL ui.Interface.frontCall("standard","launchURL",[l_url],[l_ret])

			ON ACTION open
				CALL gl_lib.gl_openFileOnClient( l_filePath )

			ON ACTION rotate_l	
				CALL img_rotate(l_filePath, TRUE)
				LET l_url = mob_app_backend.getURL(l_file, os.path.mtime( l_filePath ))
				CALL ui.Interface.frontCall("webcomponent", "call",
     				["formonly.f_wc", "setImage", l_url ], [l_ret] )

			ON ACTION rotate_r
				CALL img_rotate(l_filePath, FALSE)
				LET l_url = mob_app_backend.getURL(l_file, os.path.mtime( l_filePath ))
				CALL ui.Interface.frontCall("webcomponent", "call",
     				["formonly.f_wc", "setImage", l_url ], [l_ret] )

			ON ACTION refresh CALL get_mediaLog(l_jobid)

			ON DELETE
				LET int_flag = FALSE
				IF gl_lib.gl_winQuestion("Delete","Confirm Media File Delete?","No","Yes|No","question") = "Yes" THEN
					IF NOT os.path.delete( os.path.join(m_media_path, os.path.join( m_ml[arr_curr()].id CLIPPED,getThumbFromImg(l_file))) ) THEN
						ERROR "Failed to delete local file:",STATUS,":",os.path.join(m_media_path, os.path.join( m_ml[arr_curr()].id CLIPPED,getThumbFromImg(l_file)))
						LET int_flag = TRUE
					END IF
					IF NOT os.path.delete( os.path.join(m_media_path,l_file) ) THEN
						ERROR "Failed to delete local file:",STATUS,":",l_file
						LET int_flag = TRUE
					END IF
					IF NOT os.path.delete( os.path.join(m_media_path, m_ml[arr_curr()].id CLIPPED) ) THEN
						ERROR "Failed to delete local dir:",STATUS,":",os.path.join(m_media_path, m_ml[arr_curr()].id CLIPPED)
						LET int_flag = TRUE
					END IF
					IF int_flag THEN
						IF gl_lib.gl_winQuestion("Delete","Confirm Data Delete?","No","Yes|No","question") = "Yes" THEN
							LET int_flag = FALSE
						END IF
					END IF
					IF NOT int_flag THEN
						DELETE FROM ws_media_details WHERE md_key = m_ml[arr_curr()].key
					END IF
				ELSE
					LET int_flag = TRUE
				END IF

			ON DROP(l_dnd)
				CALL DIALOG.insertRow("arr", l_dnd.getLocationRow())
				LET m_ml[ l_dnd.getLocationRow() ].filename = l_dnd.getBuffer()
				DISPLAY "Dropped:",l_dnd.getBuffer()," into ",l_dnd.getLocationRow()		
			ON DRAG_ENTER(l_dnd)
				DISPLAY "Mime:",l_dnd.getSelectedMimeType()
				CALL l_dnd.setOperation("copy")
				{CASE
					WHEN l_dnd.selectMimeType("binary/image")
					OTHERWISE
						CALL l_dnd.setOperation(NULL)
				END CASE}

		END DISPLAY
		ON ACTION back EXIT DIALOG
	END DIALOG
	CLOSE WINDOW ml
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION cb_jobid( l_cb ui.ComboBox )
	DEFINE l_jobid LIKE ws_media_details.jobid
	CALL l_cb.clear()
	CALL l_cb.addItem("%","All")
	DECLARE cb_jobid_cur CURSOR FOR SELECT UNIQUE jobid FROM ws_media_details ORDER BY jobid
	FOREACH cb_jobid_cur INTO l_jobid
		CALL l_cb.addItem(l_jobid CLIPPED, l_jobid CLIPPED)
	END FOREACH
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION showGallery()
	DEFINE l_id, l_stat INTEGER
	DEFINE x SMALLINT
	DEFINE l_rec RECORD
		gallery_type INTEGER,
		gallery_size INTEGER,
		current INTEGER,
		gallery_wc STRING
	END RECORD
	DEFINE l_refresh BOOLEAN
	DEFINE l_struct_value fglgallery.t_struct_value

	LET l_refresh = FALSE
	OPEN WINDOW gallery WITH FORM "wc_gallery"

	DISPLAY "ImageDir:"||mob_app_backend.m_media_path TO id
	DISPLAY "FGLIMAGEPATH:"||fgl_getEnv("FGLIMAGEPATH") TO ip

	CALL fglgallery.initialize()

-- Create a gallery
	LET l_id = fglgallery.create("formonly.gallery_wc")

-- Add the images.
	FOR x = 1 TO m_ml.getLength()
--		CALL gl_lib.gl_logIt( SFMT("add image %1 to gallery",m_pics[x]))
		DISPLAY "AddToGallery:", ui.Interface.filenameToURI(m_ml[x].img),":", os.path.baseName(m_ml[x].filename)
		CALL fglgallery.addImage(l_id,
						ui.Interface.filenameToURI(m_ml[x].img), 
						os.path.basename(m_ml[x].filename)
					)
	END FOR
	DISPLAY "Added "|| m_ml.getLength()

	LET l_rec.current = 1
	LET l_rec.gallery_size = FGLGALLERY_SIZE_NORMAL
	LET l_rec.gallery_type = FGLGALLERY_TYPE_MOSAIC
-- Display the gallery to the WC.
	TRY
		CALL fglgallery.display(l_id, l_rec.gallery_type, l_rec.gallery_size)
	CATCH
		LET l_stat = STATUS
		CALL gl_lib.gl_logIt(ERR_GET(l_stat))
		CALL gl_winMessage("Error",ERR_GET(l_stat),"exclamation")
	END TRY

	INPUT BY NAME l_rec.* ATTRIBUTES (UNBUFFERED, WITHOUT DEFAULTS, ACCEPT=FALSE, CANCEL=FALSE)

		ON ACTION image_selection ATTRIBUTES(DEFAULTVIEW=NO)
			DISPLAY "image_sel:",l_rec.gallery_wc
			IF l_rec.gallery_wc.getLength() < 2 THEN
				CALL gl_winMessage("Error","Image Selection failed!","exclamation")
			ELSE
				CALL util.JSON.parse( l_rec.gallery_wc, l_struct_value )
				LET l_rec.current = l_struct_value.current
				DISPLAY os.path.join( m_ml[l_rec.current].id CLIPPED,m_ml[l_rec.current].filename CLIPPED) TO f_img
			END IF

		ON CHANGE gallery_type
			CALL fglgallery.display(l_id, l_rec.gallery_type, l_rec.gallery_size)

		ON CHANGE gallery_size
			CALL fglgallery.display(l_id, l_rec.gallery_type, l_rec.gallery_size)

		ON ACTION set_current ATTRIBUTES(DEFAULTVIEW=NO)
			LET l_struct_value.current = l_rec.current
			LET l_rec.gallery_wc = util.JSON.stringify(l_struct_value)
		ON ACTION refresh LET l_refresh = TRUE EXIT INPUT
		ON ACTION close EXIT INPUT
		ON ACTION quit EXIT INPUT
	END INPUT

	CALL fglgallery.finalize()

	CLOSE WINDOW gallery
	RETURN l_refresh
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION display_type_init(l_cb ui.ComboBox)
	CALL l_cb.addItem(FGLGALLERY_TYPE_MOSAIC,        "Mosaic")
	CALL l_cb.addItem(FGLGALLERY_TYPE_LIST,          "List")
	CALL l_cb.addItem(FGLGALLERY_TYPE_THUMBNAILS,    "Thumbnails")
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION display_size_init(l_cb ui.ComboBox )
	CALL l_cb.addItem(FGLGALLERY_SIZE_XSMALL, "X-Small")
	CALL l_cb.addItem(FGLGALLERY_SIZE_SMALL,  "Small")
	CALL l_cb.addItem(FGLGALLERY_SIZE_NORMAL, "Normal")
	CALL l_cb.addItem(FGLGALLERY_SIZE_LARGE,  "Large")
	CALL l_cb.addItem(FGLGALLERY_SIZE_XLARGE, "X-Large")
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getThumbFromImg( l_nam STRING )
	RETURN "tn_"||os.path.rootName( os.path.basename( l_nam.trim() ))||".gif"
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION img_rotate(l_file STRING, l_dir BOOLEAN)
	DEFINE l_path, l_cwd STRING
	LET l_path = os.path.dirName( l_file )
	LET l_file = os.path.baseName( l_file )
	DISPLAY "Rotate - Path:", l_path," File:",l_file
	LET l_cwd = os.path.pwd()
	IF NOT os.path.chDir( l_path ) THEN
		CALL gl_lib.gl_winMessage("Error",SFMT("Change Directory to %1 Failed!","exclamation", l_path),"exclamation")
		RETURN
	END IF
	IF NOT os.path.exists( l_file ) THEN
		CALL gl_lib.gl_winMessage("Error",SFMT("Image not found %1!","exclamation", l_file),"exclamation")
		RETURN
	END IF

	DISPLAY 'mogrify -rotate "'||IIF( l_dir, "-90","90")||'" '||l_file
	RUN 'mogrify -rotate "'||IIF( l_dir, "-90","90")||'" '||l_file

	LET l_file = getThumbFromImg( l_file )
	DISPLAY 'mogrify -rotate "'||IIF( l_dir, "-90","90")||'" '||l_file
	RUN 'mogrify -rotate "'||IIF( l_dir, "-90","90")||'" '||l_file

	LET l_dir = os.path.chDir( l_cwd ) -- change back to original dir.
END FUNCTION
-------------------------------------------------------------------------------