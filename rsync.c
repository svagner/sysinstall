/*
 * The new sysinstall program.
 *
 * This is probably the last attempt in the `sysinstall' line, the next
 * generation being slated to essentially a complete rewrite.
 *
 * $FreeBSD: stable/8/usr.sbin/sysinstall/ftp.c 153231 2005-12-08 12:43:20Z nyan $
 *
 * Copyright (c) 1995
 *	Jordan Hubbard.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer,
 *    verbatim and that no modifications are made prior to this
 *    point in the file.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY JORDAN HUBBARD ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL JORDAN HUBBARD OR HIS PETS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, LIFE OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

#include "sysinstall.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/param.h>
#include <sys/wait.h>
#include <netdb.h>
#include <pwd.h>
#include <ftpio.h>

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#include <unistd.h>

#define RSYNCPORT 873

Boolean RsyncInitted = FALSE;
static FILE *OpenConn;

static Boolean
netUp(Device *dev)
{
    Device *netdev = (Device *)dev->private;

    if (netdev)
	return DEVICE_INIT(netdev);
    else
	return TRUE;	/* No net == happy net */
}

static void
netDown(Device *dev)
{
    Device *netdev = (Device *)dev->private;

    if (netdev)
	DEVICE_SHUTDOWN(netdev);
}

Boolean
mediaInitRsync(Device *dev)
{
    struct sockaddr_in in;
    int i, code, af, fdir, sock, status, childpid, fd[2];
    char *cp, *rel, *hostname, *dir, *tmp;
    char *user, *login_name, password[80], *prompt;


    pipe(fd);

    if (RsyncInitted)
	return TRUE;

    if (OpenConn) {
	fclose(OpenConn);
	OpenConn = NULL;
    }

    /* If we can't initialize the network, bag it! */
    if (!netUp(dev))
	return FALSE;

try:
    cp = variable_get(VAR_RSYNC_PATH);
    if (!cp) {
	if (DITEM_STATUS(mediaSetRsync(NULL)) == DITEM_FAILURE || (cp = variable_get(VAR_RSYNC_PATH)) == NULL) {
	    msgConfirm("Unable to get proper Rsyncd server path.  Rsync media not initialized.");
	    netDown(dev);
	    return FALSE;
	}
    }


    hostname = variable_get(VAR_RSYNC_HOST);
    dir = variable_get(VAR_RSYNC_DIR);
    
    if (!hostname || !dir) {
	msgConfirm("Missing Rsyncd server or directory specification.  Rsync media not initialized,");
	netDown(dev);
	return FALSE;
    }

/* check host alive */
    sock = socket(PF_INET, SOCK_STREAM, 0); 
    if(sock == -1)
    {
	msgConfirm("Missing create socket.  Rsync media not initialized,");
	netDown(dev);
	return FALSE;
    }
    memset(&in, 0, sizeof(in));
    in.sin_family = AF_INET;
    in.sin_port = htons(RSYNCPORT);
    in.sin_addr.s_addr = inet_addr(hostname);
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
	msgConfirm("Couldn't create socket...");
	netDown(dev);
	return FALSE;
    }
    
    /* connect to PORT on HOST */
    if (connect(sock, (struct sockaddr *) &in, sizeof(in)) == -1) {
	msgConfirm("Server %s is not alive, or rsyncd daemon not started", hostname);
	netDown(dev);
	return FALSE;
    }
    else
    {
	close(sock);
    }

/* start checking */
    tmp = string_concat3(hostname, "::", dir);
    prompt = string_concat(tmp, "/boot/kernel/kernel");
    childpid = fork();
    if(childpid == 0) 
    {
	close(fd[0]);
	dup2(fd[1], 1);
	dup2(fd[1], 2);
	execlp("/stand/rsync", "rsync", "--list-only", prompt, (char *)0);
        close(fd[1]);
    }
    else
    {
	close(fd[1]);
	wait(&status);
    }

    if (status!=0) 
    {
	msgConfirm("Rsyncd Server directory is not valid");
	netDown(dev);
	return FALSE;
    }
    RsyncInitted = TRUE;
    return TRUE;

}

void
mediaShutdownRsync(Device *dev)
{
    if (!RsyncInitted)
	return;

    if (OpenConn != NULL) {
	fclose(OpenConn);
	OpenConn = NULL;
    }
    RsyncInitted = FALSE;
}
