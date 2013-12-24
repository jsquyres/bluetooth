/* Initially from
   http://people.csail.mit.edu/albert/bluez-intro/c404.html 

   On Raspbian, you must first:

       sudo apt-get download libbluetooth-dev
       sudo apt-get install libbluetooth-dev
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>

static void printtime(void)
{
    static int first = 1;
    static long base, last_time;
    long now, now_sec, now_usec;
    long elapsed, elapsed_sec, elapsed_usec;
    struct timeval tv;

    gettimeofday(&tv, NULL);

    now = tv.tv_sec * 1000000;
    now += tv.tv_usec;

    if (first) {
        base = now;
        now = 0;
    } else {
        now -= base;
    }
    elapsed = now - last_time;

    now_sec = now / 1000000;
    now_usec = (now - now_sec * 1000000);

    elapsed_sec = elapsed / 1000000;
    elapsed_usec = (elapsed - elapsed_sec * 1000000);

    printf("%02u.%06u (elapsed: %02u.%06u): ",
           now_sec, now_usec,
           elapsed_sec, elapsed_usec);

    last_time = now;
    first = 0;
}

int main(int argc, char **argv)
{
    inquiry_info *ii = NULL;
    int max_rsp, num_rsp;
    int dev_id, sock, len, flags;
    int i;
    char addr[19] = { 0 };
    char name[248] = { 0 };

    dev_id = hci_get_route(NULL);
    sock = hci_open_dev( dev_id );
    if (dev_id < 0 || sock < 0) {
        perror("opening socket");
        exit(1);
    }
    printtime();
    printf("Opened HCI device\n");

    len  = 8;
    /* JMS Do not set to 0!  It seems to set the OS driver in a bad
       state... */
    len  = 4;
    max_rsp = 255;
    flags = IREQ_CACHE_FLUSH;
    ii = (inquiry_info*)malloc(max_rsp * sizeof(inquiry_info));
    
    num_rsp = hci_inquiry(dev_id, len, max_rsp, NULL, &ii, flags);
    if( num_rsp < 0 ) perror("hci_inquiry");
    printtime();
    printf("Inquired\n");

    for (i = 0; i < num_rsp; i++) {
        ba2str(&(ii+i)->bdaddr, addr);
        printtime();
        printf("Querying friendly name for %s...\n", addr);
        memset(name, 0, sizeof(name));
        if (hci_read_remote_name(sock, &(ii+i)->bdaddr, sizeof(name), 
                                 name, 0) < 0)
            strcpy(name, "[unknown]");
        printf("%s  %s\n", addr, name);
    }

    printtime();
    printf("All done\n");
    free( ii );
    close( sock );
    return 0;
}

