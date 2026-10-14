#include "USBSerial.h"
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>
#include <time.h>

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
int ld_dmx_open(const char *path) {
    int fd=open(path,O_RDWR|O_NOCTTY|O_NONBLOCK);
    if(fd<0) return -1;
    struct termios t;
    if(ioctl(fd,TIOCEXCL)<0 || tcgetattr(fd,&t)<0) goto fail;
    cfmakeraw(&t); t.c_cflag &= ~(CSIZE|PARENB|CRTSCTS); t.c_cflag |= CS8|CSTOPB|CLOCAL|CREAD;
    cfsetispeed(&t,B9600); cfsetospeed(&t,B9600);
    if(tcsetattr(fd,TCSANOW,&t)<0) goto fail;
    speed_t speed=250000;
    if(ioctl(fd,IOSSIOSPEED,&speed)<0) goto fail;
    tcflush(fd,TCIOFLUSH); return fd;
fail: { int e=errno; close(fd); errno=e; return -1; }
}
int ld_dmx_write(int fd,const unsigned char *bytes,int length) {
    if(length!=513) { errno=EINVAL;return -1; }
    // Drain the previous frame before asserting BREAK. Never wait indefinitely.
    double deadline=now()+0.5; int pending=0;
    do {
        if(ioctl(fd,TIOCOUTQ,&pending)<0)return -1;
        if(!pending)break;
        if(now()>deadline){errno=ETIMEDOUT;return -1;} usleep(1000);
    }while(1);
    if(ioctl(fd,TIOCSBRK)<0)return -1;
    usleep(200); // Host-scheduled minimum; measured cable timing remains unverified.
    if(ioctl(fd,TIOCCBRK)<0)return -1;
    usleep(100);
    int sent=0;
    while(sent<length){
        ssize_t n=write(fd,bytes+sent,length-sent);
        if(n>0){sent+=(int)n;continue;}
        if(n<0 && errno==EINTR)continue;
        if(n<0 && (errno==EAGAIN || errno==EWOULDBLOCK)){
            if(now()>deadline){errno=ETIMEDOUT;return -1;}
            struct pollfd p={fd,POLLOUT,0}; if(poll(&p,1,10)<0 && errno!=EINTR)return -1; continue;
        }
        return -1;
    }
    return 0;
}
void ld_dmx_close(int fd){ if(fd>=0){ioctl(fd,TIOCCBRK);close(fd);} }
