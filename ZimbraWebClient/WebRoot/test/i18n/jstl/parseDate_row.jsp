<!--
 * ***** BEGIN LICENSE BLOCK *****
 * Zimbra Collaboration Suite Web Client
 * Copyright (C) 2008, 2009, 2010, 2012 VMware, Inc.
 * 
 * The contents of this file are subject to the Zimbra Public License
 * Version 1.3 ("License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://www.zimbra.com/license.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
 * ***** END LICENSE BLOCK *****
-->
<%@ page import="java.text.*,java.util.*" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%!
	static final Map<String,Integer> MAP = new HashMap<String,Integer>();
	static {
		MAP.put("short",	DateFormat.SHORT);
		MAP.put("medium",	DateFormat.MEDIUM);
		MAP.put("long",		DateFormat.LONG);
		MAP.put("full",		DateFormat.FULL);
	}

	static Locale getLocale(String s) {
		StringTokenizer tok = new StringTokenizer(s, "_-");
		String language = tok.nextToken();
		if (tok.hasMoreTokens()) {
			String country = tok.nextToken();
			if (tok.hasMoreTokens()) {
				String variant = tok.nextToken();
				return new Locale(language, country, variant);
			}
			return new Locale(language, country);
		}
		return new Locale(language);
	}
%>
<%
	String type = request.getParameter("type");
	int length = MAP.get(request.getParameter("length"));
	Locale locale = getLocale(request.getParameter("locale"));

	String pattern = "";
	if ("date".equals(type)) {
		pattern = ((SimpleDateFormat)DateFormat.getDateInstance(length, locale)).toPattern();
	}
	if ("time".equals(type)) {
		pattern = ((SimpleDateFormat)DateFormat.getTimeInstance(length, locale)).toPattern();
	}

	pageContext.setAttribute("pattern", pattern);
%>
<fmt:setTimeZone value="${param.timeZone}" />
<fmt:setLocale value="${param.locale}" />
<tr><th>${param.length}</th>
	<td>${pattern}</td>
	<td><fmt:formatDate var='value' value='${requestScope.now}' pattern="${pattern}" />
		${value}
	</td>
	<td><% try { %>
			<fmt:parseDate var='value' value="${value}" pattern='${pattern}' />
			<fmt:formatDate value="${value}" pattern="yyyy-MM-dd HH:mm:ss (z)" />
		<% } catch (Exception e) { %>
			<%=e.getMessage()%>
		<% } %>
	</td>
</tr>
