/*
 * ***** BEGIN LICENSE BLOCK *****
 * Zimbra Collaboration Suite Server
 * Copyright (C) 2007, 2008, 2009, 2010, 2011, 2012 VMware, Inc.
 * 
 * The contents of this file are subject to the Zimbra Public License
 * Version 1.3 ("License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://www.zimbra.com/license.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
 * ***** END LICENSE BLOCK *****
 */
package com.zimbra.cs.dav.resource;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

import org.dom4j.Element;
import org.dom4j.QName;

import com.google.common.io.Closeables;
import com.zimbra.common.service.ServiceException;
import com.zimbra.common.util.HttpUtil;
import com.zimbra.common.util.ZimbraLog;
import com.zimbra.cs.account.Account;
import com.zimbra.cs.account.Provisioning;
import com.zimbra.cs.dav.DavContext;
import com.zimbra.cs.dav.DavElements;
import com.zimbra.cs.dav.DavException;
import com.zimbra.cs.dav.DavProtocol;
import com.zimbra.cs.dav.caldav.Range.TimeRange;
import com.zimbra.cs.dav.property.CalDavProperty;
import com.zimbra.cs.dav.service.DavServlet;
import com.zimbra.cs.index.MessageHit;
import com.zimbra.cs.index.SortBy;
import com.zimbra.cs.index.ZimbraHit;
import com.zimbra.cs.index.ZimbraQueryResults;
import com.zimbra.cs.mailbox.Flag;
import com.zimbra.cs.mailbox.Folder;
import com.zimbra.cs.mailbox.MailItem;
import com.zimbra.cs.mailbox.Mailbox;
import com.zimbra.cs.mailbox.Message;
import com.zimbra.cs.mailbox.Mountpoint;

public class ScheduleInbox extends CalendarCollection {
    public ScheduleInbox(DavContext ctxt, Folder f) throws DavException, ServiceException {
        super(ctxt, f);
        addResourceType(DavElements.E_SCHEDULE_INBOX);
        String user = getOwner();
        addProperty(CalDavProperty.getCalendarFreeBusySet(user, getCalendarFolders(ctxt)));
    }

    @Override
    public java.util.Collection<DavResource> getChildren(DavContext ctxt, TimeRange tr) throws DavException {
        try {
            return getAppointmentsByUids(ctxt, null);
        } catch (ServiceException se) {
            ZimbraLog.dav.error("can't get schedule messages in folder "+getId(), se);
            return Collections.emptyList();
        }
    }

    protected static final Set<MailItem.Type> SEARCH_TYPES = EnumSet.of(MailItem.Type.MESSAGE);

    @Override
    public java.util.Collection<DavResource> getAppointmentsByUids(DavContext ctxt, List<String> hrefs) throws ServiceException, DavException {
        List<DavResource> result = new ArrayList<DavResource>();
        if (!ctxt.isSchedulingEnabled()) {
            return result;
        }
        Account target = null;
        Provisioning prov = Provisioning.getInstance();
        if (ctxt.getPathInfo() != null) {
            target = prov.getAccountByName(ctxt.getPathInfo());
        }
        String query = "is:invite is:unread inid:" + getId() + " after:\"-1month\" ";
        Mailbox mbox = getMailbox(ctxt);
        ZimbraQueryResults zqr = null;
        try {
            zqr = mbox.index.search(ctxt.getOperationContext(), query, SEARCH_TYPES, SortBy.DATE_ASC, 100);
            while (zqr.hasNext()) {
                ZimbraHit hit = zqr.getNext();
                if (hit instanceof MessageHit) {
                    Message msg = ((MessageHit)hit).getMessage();
                    if (target == null && msg.getCalendarIntendedFor() != null) {
                        continue;
                    }
                    if (!msg.isInvite() || !msg.hasCalendarItemInfos()) {
                        continue;
                    }
                    if ("REPLY".equals(msg.getCalendarItemInfo(0).getInvite().getMethod())) {
                        continue;
                    }
                    if (target != null) {
                        if (msg.getCalendarIntendedFor() == null) {
                            continue;
                        }
                        Account apptRcpt = prov.getAccountByName(msg.getCalendarIntendedFor());
                        if (apptRcpt == null || !apptRcpt.getId().equals(target.getId())) {
                            continue;
                        }
                    }
                    DavResource rs = UrlNamespace.getResourceFromMailItem(ctxt, msg);
                    if (rs != null) {
                        String href = UrlNamespace.getRawResourceUrl(rs);
                        if (hrefs == null)
                            result.add(rs);
                        else {
                            boolean found = false;
                            for (String ref : hrefs) {
                                if (HttpUtil.urlUnescape(ref).equals(href)) {
                                    result.add(rs);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found)
                                result.add(new DavResource.InvalidResource(href, getOwner()));
                        }
                    }
                }
            }
        } catch (Exception e) {
            ZimbraLog.dav.error("can't search: uri="+getUri(), e);
        } finally {
            Closeables.closeQuietly(zqr);
        }
        return result;
    }

    @Override
    public void patchProperties(DavContext ctxt, java.util.Collection<Element> set, java.util.Collection<QName> remove) throws DavException, IOException {
        ArrayList<Element> newSet = null;
        for (Element el : set) {
            if (el.getQName().equals(DavElements.E_CALENDAR_FREE_BUSY_SET)) {
                Iterator<?> hrefs = el.elementIterator(DavElements.E_HREF);
                ArrayList<String> urls = new ArrayList<String>();
                while (hrefs.hasNext())
                    urls.add(((Element)hrefs.next()).getText());
                try {
                    updateCalendarFreeBusySet(ctxt, urls);
                } catch (ServiceException e) {
                    ctxt.getResponseProp().addPropError(DavElements.E_CALENDAR_FREE_BUSY_SET, new DavException("error", DavProtocol.STATUS_FAILED_DEPENDENCY));
                } catch (DavException e) {
                    ctxt.getResponseProp().addPropError(DavElements.E_CALENDAR_FREE_BUSY_SET, e);
                }
                if (newSet == null) {
                    newSet = new ArrayList<Element>(set);
                }
                newSet.remove(el);
            }
        }
        if (newSet != null)
            set = newSet;
        super.patchProperties(ctxt, set, remove);
    }

    private void updateCalendarFreeBusySet(DavContext ctxt, ArrayList<String> urls) throws ServiceException, DavException {
        String prefix = DavServlet.DAV_PATH + "/" + getOwner();
        Mailbox mbox = getMailbox(ctxt);
        HashMap<String,Folder> folders = new HashMap<String,Folder>();
        for (Folder f : getCalendarFolders(ctxt))
            folders.put(f.getPath(), f);
        for (String url : urls) {
            if (!url.startsWith(prefix))
                continue;
            String path = url.substring(prefix.length());
            if (path.endsWith("/"))
                path = path.substring(0, path.length()-1);
            Folder f = folders.remove(path);
            if (f == null) {
                // check for recently renamed folders
                DavResource rs = UrlNamespace.checkRenamedResource(getOwner(), path);
                if (rs == null || !rs.isCollection())
                    throw new DavException("folder not found "+url, DavProtocol.STATUS_FAILED_DEPENDENCY);
                f = mbox.getFolderById(ctxt.getOperationContext(), ((MailItemResource)rs).getId());
            }
            if ((f.getFlagBitmask() & Flag.BITMASK_EXCLUDE_FREEBUSY) == 0)
                continue;
            ZimbraLog.dav.debug("clearing EXCLUDE_FREEBUSY for "+path);
            mbox.alterTag(ctxt.getOperationContext(), f.getId(), MailItem.Type.FOLDER, Flag.FlagInfo.EXCLUDE_FREEBUSY, false, null);
        }
        if (!folders.isEmpty()) {
            for (Folder f : folders.values()) {
                ZimbraLog.dav.debug("setting EXCLUDE_FREEBUSY for "+f.getPath());
                mbox.alterTag(ctxt.getOperationContext(), f.getId(), MailItem.Type.FOLDER, Flag.FlagInfo.EXCLUDE_FREEBUSY, true, null);
            }
        }
    }

    private java.util.Collection<Folder> getCalendarFolders(DavContext ctxt) throws ServiceException, DavException {
        ArrayList<Folder> calendars = new ArrayList<Folder>();
        Mailbox mbox = getMailbox(ctxt);
        for (Folder f : mbox.getFolderList(ctxt.getOperationContext(), SortBy.NONE)) {
            if (!(f instanceof Mountpoint) &&
                    (f.getDefaultView() == MailItem.Type.APPOINTMENT || f.getDefaultView() == MailItem.Type.TASK)) {
                calendars.add(f);
            }
        }
        return calendars;
    }
}
