<cfcomponent output="no" extends="VHostsConfigManager">
<!---
/*
 * TomcatConfigManager.cfc, developed by Paul Klinkenberg
 * http://www.railodeveloper.com/post.cfm/apache-iis-to-tomcat-vhost-copier-for-railo
 *
 * Date: 2010-10-10 21:03:00 +0100
 * Revision: 0.2.8
 *
 * Copyright (c) 2010 Paul Klinkenberg, Ongevraagd Advies
 * Licensed under the GPL license.
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *    ALWAYS LEAVE THIS COPYRIGHT NOTICE IN PLACE!
 */
--->	


	<!--- tomcatDefaultHostName: <Engine name="Catalina" defaultHost="localhost">...</Engine> --->
	<cfset variables.tomcatDefaultHostName = "localhost" />
	
	<!---	<Host name="www.tools.ik" appBase="webapps" unpackWARs="true" autoDeploy="true" xmlValidation="false" xmlNamespaceAware="false">
		<Context path="" docBase="/developing/tools/" />
		<!--Alias>[ENTER ALIAS DOMAIN]</Alias-->
	</Host>
	--->


	<cffunction name="writeContextXMLFile" access="public" returntype="void" output="no"
	hint="(re)writes the ROOT.xml file and containing directory in the Catalina directory for the given hostname">
		<cfargument name="host" type="string" required="yes" />
		<cfargument name="path" type="string" required="yes" />
		<cfset var hostConfRoot = getConfig().tomcatrootpath & "conf/Catalina/#arguments.host#" />
		<cfset var confContents = "<?xml version='1.0' encoding='utf-8'?>"
			& '<Context docBase="#rereplace(replace(arguments.path, '\', '/', 'all'), '/$', '')#"><WatchedResource>WEB-INF/web.xml</WatchedResource></Context>' />
		<cfif not DirectoryExists(hostConfRoot)>
			<cfdirectory action="create" directory="#hostConfRoot#" />
		</cfif>
		<cffile action="write" file="#hostConfRoot#/ROOT.xml" output="#confContents#" addnewline="no" />
	</cffunction>
	
	
	<cffunction name="removeContextXMLFile" access="public" returntype="void" output="no"
	hint="Tries to delete the ROOT.xml file and containing directory in the Catalina directory for the given hostname">
		<cfargument name="host" type="string" required="yes" />
		<cfset var hostConfRoot = getConfig().tomcatrootpath & "conf/Catalina/#arguments.host#/" />
		<cfset var qFiles = "" />
		<cfif directoryExists(hostConfRoot)>
			<cfdirectory action="list" directory="#hostConfRoot#" name="qFiles" />
			<cftry>
				<cfloop query="qFiles">
					<cfif qFiles.type eq "dir">
						<cfreturn />
					<cfelse>
						<cffile action="delete" file="#hostConfRoot##qFiles.name#" />
					</cfif>
				</cfloop>
				<cfdirectory action="delete" directory="#hostConfRoot#" />
				<cfcatch>
					<cfreturn />
				</cfcatch>
			</cftry>
		</cfif>
	</cffunction>
	
	
	<cffunction name="createTomcatVHosts" access="public" returntype="string" output="no">
		<cfargument name="VHosts" type="struct" required="yes" hint="key=hostname, value=webroot" />
		<cfset var allVHostTags = "" />
		<cfset var VHostTag = "" />
		<cfset var hostname = "" />
				
		<cfloop collection="#arguments.VHosts#" item="hostname">
			<cfsavecontent variable="VHostTag"><cfoutput>
				<Host name="<cfif hostname eq "_default_">#variables.tomcatDefaultHostName#<cfelse>#hostname#</cfif>" appBase="webapps" unpackWARs="true" autoDeploy="true" xmlValidation="false" xmlNamespaceAware="false" />
			</cfoutput></cfsavecontent>
			<cfset allVHostTags &= VHostTag />
		</cfloop>
		<cfset allVHostTags = rereplace(allVHostTags, '[\t]+', '', 'all') />
		<cfreturn allVHostTags />
	</cffunction>
	
	
	<cffunction name="overwriteVHostSettings" access="public" returntype="void">
		<cfargument name="VHostsText" type="string" required="yes" />
		<cfargument name="doBackup" type="boolean" required="no" default="yes" />
		<cfset var tomcatRoot = getConfig().tomcatrootpath />
		<cfset var tomcatFile = tomcatRoot & "conf/server.xml" />
		<cfset var tomcatConfigData = fileRead(tomcatfile) />
		<!--- remove all comments from the file --->
		<cfset var aComments = [] />
		<cfset var foundPos = "" />
		<cfloop condition="refind('<\!--.*?-->', tomcatConfigData)">
			<cfset foundPos = refind('<\!--.*?-->', tomcatConfigData, 1, true) />
			<cfset arrayAppend(aComments, mid(tomcatConfigData, foundPos.pos[1], foundPos.len[1])) />
			<cfset tomcatConfigData = replace(tomcatConfigData, aComments[arrayLen(aComments)], "$COMMENTHERE$") />
		</cfloop>
		
		<cfset var catalinaEngineRegex = "<Engine[[:space:]]+[^<>]*name=['""]Catalina['""].*?</Engine>" />
		<!--- get the part of the config file where the VHosts are stored for Railo --->
		<cfset var catalinaEngineData = rereplace(tomcatConfigData, ".+(" & catalinaEngineRegex & ").+", "\1") />
		<cfset catalinaEngineData = rereplace(catalinaEngineData, "<Host[[:space:]]([^>]+/>|.*?</Host>)", "", "all") />
		<!--- add the new hosts --->
		<cfset catalinaEngineData = replace(catalinaEngineData, "</Engine>", VHostsText & "</Engine>") />
		<!--- now change the file contents--->
		<cfset tomcatConfigData = rereplace(tomcatConfigData, catalinaEngineRegex, catalinaEngineData) />
		
		<!--- re-add the comments --->
		<cfset var arrIndex = -1 />
		<cfloop from="1" to="#arrayLen(aComments)#" index="arrIndex">
			<cfset tomcatConfigData = replace(tomcatConfigData, "$COMMENTHERE$", aComments[arrIndex]) />
		</cfloop>
		
		<!--- backup old file? --->
		<cfif arguments.doBackup>
			<cfset backupFile(tomcatfile) />
		</cfif>
		<!--- write the new config file --->
		<cfset fileWrite(tomcatFile, tomcatConfigData) />
		
		<!--- now write the <Context>s into the appropriate files --->
		
	</cffunction>


</cfcomponent>