
IMPORT os
IMPORT util

IMPORT FGL gl_lib
IMPORT FGL mob_db_backend
IMPORT FGL fglgallery

SCHEMA njm_demo310

DEFINE m_pics DYNAMIC ARRAY OF STRING
DEFINE m_imageDir STRING

MAIN

	CALL STARTLOG( base.Application.getProgramName()||".err" )

	CALL mob_db_backend.db_connect()

	LET m_imageDir = fgl_getEnv("MEDIAPATH")
	CALL gl_lib.gl_logIt(SFMT("FGLIMAGEPATH=%1",fgl_getEnv("FGLIMAGEPATH")))
	CALL getImages(m_imageDir, "gif","png")

	OPEN FORM f1 FROM "mob_ui_backend"
	DISPLAY FORM f1

	MENU %"Menu"
		ON ACTION users CALL users()
		ON ACTION accesslog CALL accessLog()
		ON ACTION medialog CALL mediaLog()
		ON ACTION gallery 
			WHILE showGallery()
				CALL getImages(m_imageDir, "gif","png")
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
-- View the Access log
-- 
-- @params 
-- @returns
FUNCTION accessLog()
	DEFINE l_al DYNAMIC ARRAY OF RECORD LIKE ws_log_access.*

	DECLARE cur_al CURSOR FOR SELECT * FROM ws_log_access 
	FOREACH cur_al INTO l_al[ l_al.getLength() + 1 ].*
	END FOREACH
	CALL l_al.deleteElement( l_al.getLength() )

	OPEN WINDOW al WITH FORM "accessLog"
	
	DISPLAY ARRAY l_al TO arr.*

	CLOSE WINDOW al
  
END FUNCTION
--------------------------------------------------------------------------------
-- View the Data log
-- {"api_param"
-- 123456789012
-- @params 
-- @returns
FUNCTION dataLog()
	DEFINE l_dl_rec RECORD LIKE ws_log_data.*
	DEFINE l_dl  DYNAMIC ARRAY OF RECORD
			username LIKE ws_log_data.username,
			data STRING,
			timestamp LIKE ws_log_data.access_date
		END RECORD
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

	LOCATE l_dl_rec.data IN MEMORY
	DECLARE cur_dl CURSOR FOR SELECT * FROM ws_log_data
	FOREACH cur_dl INTO l_dl_rec.*
		LET l_dl[ l_dl.getLength() + 1 ].username = l_dl_rec.username
		LET l_dl[ l_dl.getLength() ].data = l_dl_rec.data
		LET l_dl[ l_dl.getLength() ].timestamp = l_dl_rec.access_date
	END FOREACH

	OPEN WINDOW dl WITH FORM "dataLog"
	
	DISPLAY ARRAY l_dl TO arr.*
		BEFORE ROW
			CALL DIALOG.setActionActive("select", FALSE)
			DISPLAY l_dl[ arr_curr() ].data TO f_data
			LET l_url = NULL
			IF l_dl[ arr_curr() ].data.subString(1,12) = "{\"api_param\"" THEN
				TRY
					CALL util.JSON.parse(l_dl[ arr_curr() ].data, l_sc_rec )
					LET l_url = l_sc_rec.reply.link
				CATCH
					ERROR "Invalid JSON!"
				END TRY
			END IF
			IF l_dl[ arr_curr() ].data.subString(1,8) = "https://" THEN
				LET l_url = l_dl[ arr_curr() ].data
			END IF
			IF l_url iS NOT NULL THEN
				CALL DIALOG.setActionActive("select", TRUE)
			END IF
		ON ACTION select
				CALL ui.Interface.frontCall("standard", "launchURL", [ l_url ], l_ret)
	END DISPLAY

	CLOSE WINDOW dl
  
END FUNCTION
--------------------------------------------------------------------------------
-- View the Media log
--
-- @params
-- @returns
FUNCTION mediaLog()
  DEFINE l_ml DYNAMIC ARRAY OF RECORD 
			user_name LIKE ws_log_media.username,
			media_type LIKE ws_log_media.media_type,
			filepath LIKE ws_log_media.filepath,
			access_date LIKE ws_log_media.access_date,
			img STRING
		END RECORD
	DEFINE l_thumb STRING

	DECLARE cur_ml CURSOR FOR SELECT * FROM ws_log_media 
	FOREACH cur_ml INTO l_ml[ l_ml.getLength() + 1 ].*
		LET l_thumb = os.path.join( 
					os.path.dirName(l_ml[ l_ml.getLength() ].filepath),
					"tn_"||os.path.rootName( os.path.basename( l_ml[ l_ml.getLength() ].filepath ) ).append(".gif"))
		IF os.path.exists( l_thumb ) THEN
			DISPLAY l_thumb||" Okay"
		ELSE
			DISPLAY l_thumb||" Missing"
		END IF
		LET l_ml[ l_ml.getLength() ].img = l_thumb
	END FOREACH
	CALL l_ml.deleteElement( l_ml.getLength() )

	OPEN WINDOW ml WITH FORM "mediaLog"
	
	DISPLAY ARRAY l_ml TO arr.*
		BEFORE ROW 
			IF l_ml[arr_curr()].media_type = "P" THEN
				DISPLAY l_ml[arr_curr()].filepath TO f_img
			END IF
	END DISPLAY

	CLOSE WINDOW ml
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

	DISPLAY "ImageDir:"||m_imageDir TO id
	DISPLAY "FGLIMAGEPATH:"||fgl_getEnv("FGLIMAGEPATH") TO ip

	CALL fglgallery.initialize()

-- Create a gallery
	LET l_id = fglgallery.create("formonly.gallery_wc")

-- Add the images.
	FOR x = 1 TO m_pics.getLength()
--		CALL gl_lib.gl_logIt( SFMT("add image %1 to gallery",m_pics[x]))
		CALL fglgallery.addImage(l_id, 
--					ui.Interface.filenameToURI(os.path.join(c_imageDir,m_pics[x])), 
						ui.Interface.filenameToURI(m_pics[x]), 
						getImgFromThumb( m_pics[x] ) --	"Image "||x
					)
	END FOR
	DISPLAY "Added "|| m_pics.getLength()

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
				DISPLAY getImgFromThumb( m_pics[ l_rec.current ] ) TO f_img
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
FUNCTION getImgFromThumb( l_nam STRING )
	IF l_nam.subString(1,3) = "tn_" THEN
		LET l_nam = l_nam.subString(4, l_nam.getLength())
	END IF
	RETURN os.path.rootname( l_nam )
END FUNCTION
--------------------------------------------------------------------------------
-- Set the m_pics array to all images of extention type p_ext or p_ext2.
FUNCTION getImages(l_imageDir STRING, p_ext STRING, p_ext2 STRING)
	DEFINE l_ext, l_path STRING
	DEFINE d SMALLINT

	CALL m_pics.clear()
	CALL gl_lib.gl_logIt(SFMT("getting image array from %1",m_imageDir))
	CALL os.Path.dirSort( "name", 1 )
	LET d = os.Path.dirOpen( l_imageDir )
	IF d > 0 THEN
		WHILE TRUE
			LET l_path = os.Path.dirNext( d )
			IF l_path IS NULL THEN EXIT WHILE END IF

			IF os.path.isDirectory( l_path ) THEN 
			--	DISPLAY "Dir:",l_path
				CONTINUE WHILE 
			ELSE
				--DISPLAY "Fil:",l_path
			END IF

			LET l_ext = os.path.extension( l_path )
			IF l_ext IS NULL OR (p_ext != l_ext AND p_ext2 != l_ext) THEN CONTINUE WHILE END IF

			LET m_pics[ m_pics.getLength() + 1 ] = l_path

		END WHILE
	ELSE
		CALL gl_winMessage("Error",SFMT("Failed to open directory %1",l_imageDir),"exclamation")
		EXIT PROGRAM
	END IF
	IF m_pics.getLength() = 0 THEN
		CALL gl_winMessage("Error",SFMT("No images found in:%1",m_imageDir),"exclamation")
	END IF
	CALL gl_lib.gl_logIt(SFMT("got %1 images.",m_pics.getLength()))

END FUNCTION