<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<title>Webserver2Tomconfig file to get it's settings fromcatVHostCopier test page</title>
	<style type="text/css">
		body { font-size:12px; font-family:Verdana, Geneva, sans-serif; }
		pre { background-color:#eee; padding:5px; width:auto; max-height:150px; overflow:auto; border:1px solid #000; }
		h1, h2, h3 { padding: 6px 0px 6px 15px; background-color:#CCC; margin:25px 0px 10px 0px; }
	</style>
</head>
<body>
	<h1>Test page for the Webserver2TomcatVHostCopier</h1>
	
	<cfif structKeyExists(form, "configdata")>
		<cftry>
			<h3>Your parsing results</h3>
			<!--- delete the old log file --->
			<cfif fileExists('parserLog.log')>
				<cfset fileDelete('parserLog.log') />
				<em>parser log was cleared</em><br />
			</cfif>
			<!--- write the new configuration to disk --->
			<cfset fileWrite('config.conf', form.configdata) />
			<!--- can we send debug data to the developer? --->
			<cfset variables.emailErrors = structKeyExists(form, "sendErrorsToPaul") />
			<!--- call the copier, but only to test the config --->
			<cfset new Webserver2TomcatVHostCopier().copyWebserverVHosts2Tomcat(testOnly=true, sendCriticalErrors=variables.emailErrors) />
			
			<br />--&gt; Don't forget to look at the parser log underneath this page!
			
			<!--- error occured? --->
			<cfcatch>
				<h3 style="color:red;">An error occured :-(</h3>
				<cfif structKeyExists(form, "sendErrorsToPaul")>
					<cfmail to="paul@ongevraagdadvies.nl" from="paul@ongevraagdadvies.nl" subject="Webserver2Tomcat error at #cgi.http_host#" type="html">
						Date: #now()#<br />
						<cfdump var="#form#" label="form data" />
						<cfdump var="#cfcatch#" label="error data" />
						<cfdump var="#cgi#" label="cgi vars" />
					</cfmail>
					<p>A mail about this has been sent to the developer</p>
				</cfif>
				<cfdump var="#cfcatch#" abort />
			</cfcatch>
		</cftry>
	</cfif>
	
	<h3>Test the parsing of your webserver configuration</h3>
	<p>Please edit the following config file, and then press "TEST". Also see the requirements underneath this page.</p>
	
	<form method="post" action="test.cfm">
		<label for="sendErrorsToPaul"><input id="sendErrorsToPaul" type="checkbox" name="sendErrorsToPaul" value="1" checked="checked" />
			Send errors to the developer for debugging purposes?
		</label><br />
		<textarea cols="60" rows="8" name="configdata"><cfif fileExists('config.conf')><cfoutput>#fileRead('config.conf')#</cfoutput></cfif></textarea>
		<br /><input type="submit" value="TEST" />
	</form>
	
	<h3>Example configuration</h3>
	<pre>webservertype=IIS7 (or IIS6 or Apache)
httpdfile=/private/etc/apache2/httpd.conf
IIS7File=%systemroot%\System32\inetsrv\config\applicationHost.config
IIS6File=%systemroot%\System32\inetsrv\Metabase.xml
tomcatrootpath=/Applications/tomcat/</pre>
	<em>(which lines are actually used depends on the first line, 'webservertype')</em>
	
	<h3>Parser log</h3>
	<cfif fileExists('parserLog.log')>
		<cfoutput><textarea cols="100" rows="8">#fileRead('parserLog.log')#</textarea></cfoutput>
	<cfelse>
		<em>no log created</em>
	</cfif>

	<h3>Requirements</h3>
	<ul>
		<li>The tomcat hostmanager must be enabled and running. Check this by going to http://localhost:8080/host-manager/html (or your own custom tomcat port)</li>
		<li>You must have a valid user for the host-manager: add or edit the file {tomcat installation directory}/conf/tomcat-users.xml to contain the following:<br />
			&lt;tomcat-users&gt;&lt;role rolename=&quot;manager&quot;/&gt;&lt;role rolename=&quot;admin&quot;/&gt;&lt;user name=&quot;SOME NAME&quot; password=&quot;SOME PASSWORD&quot; roles=&quot;admin,manager&quot;/&gt;&lt;/tomcat-users&gt;</li>
		<li>createObject() function must be allowed (not sandboxed)</li>
		<li>&lt;cfinvoke&gt; tag must be allowed (not sandboxed)</li>
		<li>Railo must have read access to the Apache or IIS config files (you will supply the paths in the next step, so you will know what paths to allow)</li>
		<li>Railo must have write access to Tomcat's server.xml file</li>
	</ul>
</body>
</html>