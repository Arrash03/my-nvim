/*
 * netguard.c -- LD_PRELOAD network blocker for nvim-forge offline tests.
 *
 * Interposes connect()/sendto()/sendmsg() so that any attempt to talk to an
 * IPv4/IPv6 endpoint fails with EACCES and is appended to $NVF_NETGUARD_LOG.
 * Unix-domain sockets and local IPC keep working (LSP uses stdio pipes, not
 * sockets; Neovim's own loopback UI is not used in the headless tests).
 *
 * socket() itself is only *logged*, not blocked: some libraries probe address
 * families harmlessly.  The log therefore records both "tried to open" and
 * "tried to talk"; a clean run has zero of either.
 *
 * Built against glibc 2.35 (Ubuntu 22.04 sandbox) so it loads on any target.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

static void ng_log(const char *what, int domain)
{
    const char *path = getenv("NVF_NETGUARD_LOG");
    if (!path || !*path)
        return;
    FILE *f = fopen(path, "a");
    if (!f)
        return;
    fprintf(f, "%s domain=%d pid=%d\n", what, domain, (int)getpid());
    fclose(f);
}

static int ng_inet(int domain)
{
    return domain == AF_INET || domain == AF_INET6;
}

int socket(int domain, int type, int protocol)
{
    static int (*real_socket)(int, int, int) = NULL;
    if (!real_socket)
        real_socket = (int (*)(int, int, int))dlsym(RTLD_NEXT, "socket");
    if (ng_inet(domain)) {
        ng_log("socket", domain);
        errno = EAFNOSUPPORT;
        return -1;
    }
    return real_socket(domain, type, protocol);
}

int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
    static int (*real_connect)(int, const struct sockaddr *, socklen_t) = NULL;
    if (!real_connect)
        real_connect = (int (*)(int, const struct sockaddr *, socklen_t))
            dlsym(RTLD_NEXT, "connect");
    if (addr && ng_inet(addr->sa_family)) {
        ng_log("connect", addr->sa_family);
        errno = EACCES;
        return -1;
    }
    return real_connect(sockfd, addr, addrlen);
}

ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest, socklen_t destlen)
{
    static ssize_t (*real_sendto)(int, const void *, size_t, int,
                                  const struct sockaddr *, socklen_t) = NULL;
    if (!real_sendto)
        real_sendto = (ssize_t (*)(int, const void *, size_t, int,
                                   const struct sockaddr *, socklen_t))
            dlsym(RTLD_NEXT, "sendto");
    if (dest && ng_inet(dest->sa_family)) {
        ng_log("sendto", dest->sa_family);
        errno = EACCES;
        return -1;
    }
    return real_sendto(sockfd, buf, len, flags, dest, destlen);
}

ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags)
{
    static ssize_t (*real_sendmsg)(int, const struct msghdr *, int) = NULL;
    if (!real_sendmsg)
        real_sendmsg = (ssize_t (*)(int, const struct msghdr *, int))
            dlsym(RTLD_NEXT, "sendmsg");
    if (msg && msg->msg_name) {
        const struct sockaddr *a = (const struct sockaddr *)msg->msg_name;
        if (ng_inet(a->sa_family)) {
            ng_log("sendmsg", a->sa_family);
            errno = EACCES;
            return -1;
        }
    }
    return real_sendmsg(sockfd, msg, flags);
}
