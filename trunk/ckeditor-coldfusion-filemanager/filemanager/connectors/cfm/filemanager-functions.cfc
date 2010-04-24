<!---
 *	Filemanager CFM connector
 *
 *	filemanager-functions.cfc
 *	use for ckeditor filemanager plug-in by Core Five - http://labs.corefive.com/Projects/FileManager/
 *
 *	@license	MIT License
 *	@author		Paul Klinkenberg, www.coldfusiondeveloper.nl/post.cfm/cfm-connector-for-ckeditor-corefive-Filemanager
 *  @date		February 28, 2010
 *  @version	1.0
 *	@copyright	Authors
---><cfcomponent output="no" hint="functions for the cfml filemanager connector">
	
	<cfset variables.translations = structNew() />
	<cfset variables.separator = createObject("java", "java.io.File").separator />
	<cfset variables.imageInfo_struct = structNew() />
		
	
	<cffunction name="translate" access="public" returntype="string">
		<cfargument name="key" type="string" required="yes" />
		<cfset var lang = structNew() />
		<cfset var ret_str = "" />
		<cfset var findCount = 0 />
		<cfset var pathFromWebRoot = "" />
		
		<cfif not structKeyExists(variables.translations, request.language)>
			<cfset pathFromWebRoot = replace(replace(getDirectoryFromPath(GetCurrentTemplatePath()), expandPath('/'), "/"), "\", "/", "all") />
			<cfinclude template="#pathFromWebRoot#lang/#request.language#.cfm" />
			<cfset structInsert(variables.translations, request.language, lang, true) />
		</cfif>
		
		<cfset ret_str = variables.translations[request.language][arguments.key] />
		<cfloop condition="refind('\%s', ret_str)">
			<cfset findCount=findCount+1 />
			<cfset ret_str = replace(ret_str, '%s', arguments[findCount+1]) />
		</cfloop>
		<cfreturn ret_str />
	</cffunction>
	
	
	<cffunction name="returnError" returntype="void" access="public">
		<cfargument name="str" required="yes" type="string" />
		<cfargument name="textarea" type="boolean" required="no" default="false" />
		<cfset var returnData_struct = structNew() />
		<cfset structInsert(returnData_struct, "Error", arguments.str) />
		<cfset structInsert(returnData_struct, "Code", -1) />
		<cfset _doOutput(jsonData=returnData_struct, textarea=arguments.textarea) />
	</cffunction>
	
	
	<cffunction name="download" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfset var absPath = _getPath(arguments.path) />
		<!--- check if file exists --->
		<cfif not fileExists(absPath)>
			<cfset returnError(translate('FILE_DOES_NOT_EXIST', arguments.path)) />
		</cfif>
		<!--- pass the file through for download --->
		<cfheader name="Content-Disposition" value="attachment;filename=#listLast(absPath, '/\')#" />
		<cfcontent reset="yes" type="application/x-download-#listLast(absPath, '.')#" file="#absPath#" deletefile="no" />
	</cffunction>
	
	
	<cffunction name="delete" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfset var absPath = _getPath(arguments.path) />
		<cfset var parentPath = _getParentPath(absPath) />
		<cfset var filename = listLast(absPath, variables.separator) />
		<cfset var isDir = _isDirectory(absPath) />
		<cfset var dirlist_qry = "" />
		<cfset var jsondata_struct = "" />
		<cfset var shortenedWebPath = replaceNoCase(arguments.path, request.uploadWebRoot, "/") />
		
		<cfif isDir>
			<!--- check if dir exists --->
			<cfif not DirectoryExists(absPath)>
				<cfset returnError(translate('DIRECTORY_NOT_EXIST', arguments.path)) />
			</cfif>
			<!--- check if directory is empty --->
			<cfdirectory action="list" directory="#absPath#" name="dirlist_qry" />
			<cfloop query="dirlist_qry">
				<cfif not listfind(".,..", dirlist_qry.name, ",")>
					<cfset returnError(translate('DIRECTORY_NOT_EMPTY', arguments.path)) />
				</cfif>
			</cfloop>
			<!--- delete dir --->
			<cftry>
				<cfdirectory action="delete" directory="#absPath#" />
				<cfcatch>
					<cfset returnError(translate('DIRECTORY_NOT_DELETED', arguments.path)) />
				</cfcatch>
			</cftry>
		<cfelse>
			<!--- check if file exists --->
			<cfif not fileExists(absPath)>
				<cfset returnError(translate('FILE_DOES_NOT_EXIST', arguments.path)) />
			</cfif>
			<!--- delete file --->
			<cftry>
				<cffile action="delete" file="#absPath#" />
				<cfcatch>
					<cfset returnError(translate('FILE_NOT_DELETED', arguments.path)) />
				</cfcatch>
			</cftry>
			<cfset _clearImageInfoCache(arguments.path) />
		</cfif>
		
		<cfset jsondata_struct = structNew() />
		<cfset structInsert(jsondata_struct, "Error", "") />
		<cfset structInsert(jsondata_struct, "Code", 0) />
		<cfset structInsert(jsondata_struct, "Path", shortenedWebPath) />
		<cfset _doOutput(jsondata_struct) />
	</cffunction>
	
	
	<cffunction name="getInfo" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="getsize" type="boolean" required="no" default="true" />
		<cfset var dirPath = _getParentPath(arguments.path) />
		<cfset var filename = listLast(arguments.path, "/") />
		<cfset var data_struct = _getDirectoryInfo(path=dirPath, getsizes=arguments.getsize, filter=filename) />
		<cfset var key = "" />
		
		<cfif structIsEmpty(data_struct)>
			<cfset returnError(translate('FILE_DOES_NOT_EXIST', arguments.path)) />
		</cfif>
		
		<cfloop collection="#data_struct#" item="key">
			<cfset _doOutput(data_struct[key]) />
		</cfloop>
	</cffunction>
	
	
	<cffunction name="getFolder" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="getsizes" type="boolean" required="no" default="true" />
		<cfset var data_struct = _getDirectoryInfo(argumentcollection=arguments) />
		
		<cfset _doOutput(data_struct) />
	</cffunction>
	
	
	<cffunction name="_getDirectoryInfo" returntype="struct" access="private">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="getsizes" type="boolean" required="yes" />
		<cfargument name="filter" type="string" required="no" default="" />
		<cfset var dirPath = _getPath(arguments.path) />
		<cfset var dirlist_qry = "" />
		<cfset var data_struct = structNew() />
		<cfset var currData_struct = "" />
		<cfset var imageData_struct = "" />
		<cfset var webDirPath = _getWebPath(path) />

		<cfif not DirectoryExists(dirPath)>
			<cfset returnError(translate('DIRECTORY_NOT_EXIST', dirPath)) />
		</cfif>
		
		<cftry>
			<cfdirectory action="list" directory="#dirPath#" name="dirlist_qry" sort="Name" filter="#arguments.filter#" />
			<cfcatch>
				<cfset returnError(translate('UNABLE_TO_OPEN_DIRECTORY', arguments.path)) />
			</cfcatch>
		</cftry>
		
		<cfloop query="dirlist_qry">
			<cfset currData_struct = structNew() />
			<cfset data_struct[arguments.path & dirlist_qry.name] = currData_struct />

			<cfset structInsert(currData_struct, "Filename", dirlist_qry.name) />
			<cfset structInsert(currData_struct, "Error", "") />
			<cfset structInsert(currData_struct, "Code", 0) />
			<cfset structInsert(currData_struct, "Properties", structNew()) />
				<cfset structInsert(currData_struct.Properties, "Date Created", "") />
				<cfset structInsert(currData_struct.Properties, "Date Modified", "#lsdateformat(dateLastModified, 'medium')# #timeformat(dateLastModified, 'HH:mm:ss')#") />
				<cfset structInsert(currData_struct.Properties, "Height", "") />
				<cfset structInsert(currData_struct.Properties, "Width", "") />
			<cfif dirlist_qry.type eq "DIR">
				<cfset structInsert(currData_struct, "Path", webDirPath & dirlist_qry.name & "/") />
				<cfset structInsert(currData_struct, "File Type", "dir") />
				<cfset structInsert(currData_struct, "Preview", request.directoryIcon) />
				<cfset structInsert(currData_struct.Properties, "Size", "") />
			<cfelse>
				<cfset structInsert(currData_struct, "Path", webDirPath & dirlist_qry.name) />
				<cfset structInsert(currData_struct, "File Type", lCase(listlast(dirlist_qry.name, '.'))) />
				<cfset structInsert(currData_struct.Properties, "Size", dirlist_qry.size) />
				<cfif _isImage(dirlist_qry.directory & variables.separator & dirlist_qry.name)>
					<cfset structInsert(currData_struct, "Preview", webDirPath & dirlist_qry.name) />
					<cfif arguments.getsizes>
						<cfset imageData_struct = _getImageInfo(dirlist_qry.directory & variables.separator & dirlist_qry.name) />
						<cfset structInsert(currData_struct.Properties, "Height", imageData_struct.height, true) />
						<cfset structInsert(currData_struct.Properties, "Width", imageData_struct.width, true) />
					</cfif>
				<cfelse>
					<cfset structInsert(currData_struct, "Preview", request.defaultIcon) />
				</cfif>
			</cfif>
		</cfloop>
		
		<cfreturn data_struct />
	</cffunction>
	
	
	<cffunction name="rename" returntype="void" access="public">
		<cfargument name="oldPath" type="string" required="yes" />
		<cfargument name="newName" required="yes" type="string" />
		<cfset var oldDirPath = _getPath(arguments.oldPath) />
		<cfset var oldParentPath = _getParentPath(arguments.oldPath) />
		<cfset var parentDirPath = _getPath(oldParentPath) />
		<cfset var fileOrDirName = listlast(oldDirPath, variables.separator) />
		<cfset var isDir = _isDirectory(oldDirPath) />
		<cfset var dirList_qry = "" />
		<cfset var returnData_struct = structNew() />

		<!--- make sure the newName has no illegal characters--->
		<cfset arguments.newName = rereplace(arguments.newName, "[^a-zA-Z0-9\-_]+", "-", "ALL") />
		
		<cfif isDir>
			<cfif not DirectoryExists(oldDirPath)>
				<cfset returnError(translate('DIRECTORY_NOT_EXIST', arguments.oldPath)) />
			<cfelseif directoryExists(parentDirPath & arguments.newName)>
				<cfset returnError(translate('DIRECTORY_ALREADY_EXISTS', oldParentPath & arguments.newName)) />
			<cfelseif listLast(oldDirPath, variables.separator) neq arguments.newName>
				<cftry>
					<cfdirectory action="rename" directory="#oldDirPath#" newdirectory="#arguments.newName#" />
					<cfcatch>
						<cfset returnError(translate('ERROR_RENAMING_DIRECTORY', arguments.oldPath, arguments.newName)) />
					</cfcatch>
				</cftry>
			</cfif>
		<cfelse>
			<!--- re-add file extension, if the extension is still the same --->
			<cfif refindNoCase("\.[a-z0-9]+$", oldPath)>
				<cfset arguments.newName = rereplaceNoCase(arguments.newName, "\-(#listLast(oldPath, '.')#)$", ".\1") />
				<!--- check if extension is still the same --->
				<cfif listLast(oldPath, '.') neq listLast(arguments.newName, '.')>
					<cfset arguments.newName = arguments.newName & "." & listLast(oldPath, '.') />
				</cfif>
			</cfif>
			<cfif not fileExists(oldDirPath)>
				<cfset returnError(translate('FILE_DOES_NOT_EXIST', oldParentPath & arguments.newName)) />
			<cfelseif fileExists(parentDirPath & arguments.newName)>
				<cfset returnError(translate('FILE_ALREADY_EXISTS', parentDirPath & arguments.newName)) />
			<cfelseif listLast(oldDirPath, variables.separator) neq arguments.newName>
				<cftry>
					<cffile action="rename" source="#oldDirPath#" destination="#parentDirPath##arguments.newName#" />
					<cfcatch>
					<cfrethrow />
						<cfset returnError(translate('ERROR_RENAMING_FILE', arguments.oldPath, arguments.newName)) />
					</cfcatch>
				</cftry>
				<cfset _clearImageInfoCache(arguments.oldPath) />
			</cfif>
		</cfif>

		<!--- response to client --->
		<cfset returnData_struct = structNew() />
		<cfset structInsert(returnData_struct, "Error", "") />
		<cfset structInsert(returnData_struct, "Code", 0) />
		<cfset structInsert(returnData_struct, "Old Path", arguments.oldPath) />
		<cfset structInsert(returnData_struct, "Old Name", fileOrDirName) />
		<cfset structInsert(returnData_struct, "New Path", "#oldParentPath##arguments.newName#") />
		<cfset structInsert(returnData_struct, "New Name", arguments.newName) />
		<cfset _doOutput(returnData_struct) />
	</cffunction>
	
	
	<cffunction name="addFolder" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="dirname" required="yes" type="string" />
		<cfset var newDirPath = "" />
		<cfset var returnData_struct = structNew() />
		
		<cfset arguments.dirName = rereplace(arguments.dirName, "[^a-zA-Z0-9-_]+", "-", "ALL") />
		<cfset newDirPath = _getPath(arguments.path, arguments.dirname) />

		<cfif directoryExists(newDirPath)>
			<cfset returnError(translate('DIRECTORY_ALREADY_EXISTS', arguments.path & arguments.dirname)) />
		</cfif>
		<cftry>
			<cfdirectory action="create" directory="#newDirPath#" recurse="no" />
			<cfcatch>
				<cfset returnError(translate('UNABLE_TO_CREATE_DIRECTORY', arguments.dirname)) />
			</cfcatch>
		</cftry>
		
		<!--- response to client --->
		<cfset returnData_struct = structNew() />
		<cfset structInsert(returnData_struct, "Error", "") />
		<cfset structInsert(returnData_struct, "Code", 0) />
		<cfset structInsert(returnData_struct, "Parent", arguments.path) />
		<cfset structInsert(returnData_struct, "Name", arguments.dirName) />
		<cfset _doOutput(returnData_struct) />
	</cffunction>
	
	
	<cffunction name="addFile" returntype="void" access="public">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="formfieldname" required="yes" type="string" />
		<cfset var file_struct = "" />
		<cfset var newFileName = "" />
		<cfset var loopCounter_num = 0 />
		<cfset var returnData_struct = structNew() />

		<!--- upload the file --->
		<cftry>
			<cffile action="upload" destination="#getTempDirectory()#" filefield="#formfieldname#" nameconflict="makeunique" result="file_struct" />
			<cfcatch>
				<cfset returnError(str=translate('INVALID_FILE_UPLOAD'), textarea=true) />
			</cfcatch>
		</cftry>
		<!--- check for max file size --->
		<cfif file_struct.filesize gt request.maxFileSizeKB*1024>
			<cfset returnError(str=translate('UPLOAD_FILES_SMALLER_THAN', request.maxFileSizeKB & "KB"), textarea=true) />
		</cfif>
		<!--- check for allowed extensions --->
		<cfif not request.allowAllFiles and not listFindNoCase(request.allowedExtensions, file_struct.serverfileExt)>
			<cfset returnError(str=translate('INVALID_FILE_UPLOAD'), textarea=true) />
		</cfif>
		<!--- check if it is/should be an image --->
		<cfif request.onlyImageUploads or (structKeyExists(form, "type") and form.type eq "Images")>
			<cfif not listFindNoCase(request.allowedImageExtensions, file_struct.serverfileExt)>
				<cfset returnError(str=translate('UPLOAD_IMAGES_TYPES_ABC', request.allowedImageExtensions), textarea=true) />
			</cfif>
		</cfif>
		<cfset newFileName = rereplace(file_struct.serverfileName, "[^a-zA-Z0-9-_]+", "-", "all") & ".#file_struct.serverFileExt#" />
		<!--- if overwriting an existing file --->
		<cfif fileExists(_getPath(arguments.path, newFileName))>
			<cfif request.uploadCanOverwrite>
				<cffile action="delete" file="#_getPath(arguments.path, newFileName)#" />
				<cfset _clearImageInfoCache(arguments.path & newFileName) />
			<cfelse>
				<cfloop condition="fileExists(_getPath(arguments.path, newFileName))">
					<cfset loopCounter_num=loopCounter_num+1 />
					<cfset newFileName = rereplace(newFileName, "(#loopCounter_num-1#)?\.", "#loopCounter_num#.") />
				</cfloop>
			</cfif>
		</cfif>
		<!--- create the destination directory if it does not exist yet --->
		<cfif not DirectoryExists(_getPath(arguments.path))>
			<cfdirectory action="create" directory="#_getPath(arguments.path)#" recurse="yes" />
		</cfif>
		<!--- move the file from Temp to the actual dir. --->
		<cffile action="move" source="#file_struct.serverDirectory##variables.separator##file_struct.serverFile#"
		destination="#_getPath(arguments.path, newFileName)#" />
		
		<!--- response to client --->
		<cfset returnData_struct = structNew() />
		<cfset structInsert(returnData_struct, "Error", "") />
		<cfset structInsert(returnData_struct, "Code", 0) />
		<cfset structInsert(returnData_struct, "Path", arguments.path) />
		<cfset structInsert(returnData_struct, "Name", newFileName) />
		<cfset _doOutput(jsondata=returnData_struct, textarea=true) />
	</cffunction>
	
	
	<cffunction name="_getPath" access="private" returntype="string">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="filename" type="string" required="no" default="" />
		<cfset var newPath_str = "" />
		<!--- remove any "../" and "..\" from the given path --->
		<cfset arguments.path = rereplace(arguments.path, "\.\.+([/\\])", "\1", " all") />
		
		<cfif findNoCase(request.uploadWebRoot, arguments.path) eq 1>
			<cfset newPath_str = request.uploadRootPath & variables.separator & replaceNoCase(arguments.path, request.uploadWebRoot, "/") />
		<cfelse>
			<cfset newPath_str = request.uploadRootPath & variables.separator & arguments.path />
		</cfif>
		
		<cfif len(filename)>
			<cfset newPath_str = newPath_str & variables.separator & arguments.filename />
		<!--- if not a specific file given, check if the given path ends with a slash or a name with a dot in it --->
		<cfelseif not refind("[/\\][^/\\\.]+$", newPath_str)>
			<cfset newPath_str = newPath_str & variables.separator />
		</cfif>
		<cfset newPath_str = rereplace(newPath_str, '[/\\]+', variables.separator, "all") />
		<cfreturn newPath_str />
	</cffunction>
	
	
	<cffunction name="_getWebPath" access="private" returntype="string">
		<cfargument name="path" type="string" required="yes" />
		<cfargument name="filename" type="string" required="no" default="" />
		<cfset var absPath_str = _getPath(arguments.path, arguments.filename) />
		<cfset var webPath_str = replace(replace(absPath_str, expandPath('/'), "/"), "\", "/", "all") />
		<cfreturn webPath_str />
	</cffunction>
	
	
	<cffunction name="_isImage" access="private" returntype="boolean">
		<cfargument name="path" required="yes" type="string" />
		<cfreturn (listFindNoCase("png,jpg,jpeg,gif", listlast(path, '.')) gt 0) />
	</cffunction>


	<cffunction name="_getImageInfo" access="private" returntype="struct">
		<cfargument name="path" required="yes" type="string" />
		<cfset var cfimage_struct = "" />
		<cfset var imageData_struct = structNew() />
		<cfif not structKeyExists(variables.imageInfo_struct, arguments.path)>
			<cfimage action="info" source="#arguments.path#" structname="cfimage_struct" />
			<!--- workaround for railobug #611: https://jira.jboss.org/jira/browse/RAILO-611 --->
			<cfif structKeyExists(server, "Railo")>
				<cfset cfimage_struct = duplicate(cfimage_struct) />
			</cfif>
			<cfset structInsert(imageData_struct, "Width", cfimage_struct.width) />
			<cfset structInsert(imageData_struct, "Height", cfimage_struct.height) />
			<cfset structInsert(variables.imageInfo_struct, arguments.path, imageData_struct, true) />
		</cfif>
		<cfreturn variables.imageInfo_struct[arguments.path] />
	</cffunction>
	
	
	<cffunction name="_clearImageInfoCache" access="private" returntype="void">
		<cfargument name="path" required="no" type="string" />
		<cfif structKeyExists(arguments, "path")>
			<cfset StructDelete(variables.imageInfo_struct, arguments.path, false) />
		<cfelse>
			<cfset structClear(variables.imageInfo_struct) />
		</cfif>
	</cffunction>
	

	<cffunction name="_isDirectory" access="private" returntype="boolean">
		<cfargument name="absPath" type="string" required="yes" />
		<cfset var parentPath = _getParentPath(arguments.absPath) />
		<cfset var fileOrDirName = listlast(arguments.absPath, variables.separator) />
		<cfset var dirList_qry = "" />
		<!--- check if it is a directory --->
		<cfdirectory action="list" name="dirList_qry" directory="#parentPath#" filter="#fileOrDirName#" />
		<cfreturn (dirlist_qry.recordcount and dirList_qry.type eq "DIR") />
	</cffunction>


	<cffunction name="_doOutput" access="public" returntype="void">
		<cfargument name="jsonData" type="any" required="yes" />
		<cfargument name="textarea" type="boolean" required="no" default="false" />
		<cfset var ret_str = SerializeJSON(jsonData) />
		<cfif arguments.textarea>
			<cfset ret_str = "<textarea>" & ret_str & "</textarea>" />
		</cfif>
		<!--- the real output to screen --->
		<cfcontent reset="yes" type="#iif(arguments.textarea, de('text/html'), de('application/json'))#" /><!---
		---><cfoutput>#ret_str#</cfoutput><!---
		---><cfabort />
	</cffunction>
	
	
	<cffunction name="_getParentPath" access="private" returntype="string">
		<cfreturn rereplace(arguments[1], '[^/\\]+[/\\]?$', '') />
	</cffunction>
	

</cfcomponent>