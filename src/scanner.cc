/*
 * Scanner tool for science experiments
 *
 * Jeff Squyres (c) 2013
 *
 * Strongly influenced by hcitool.c from the bluez toolkit.
 */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <errno.h>
#include <sys/time.h>
#include <getopt.h>

#include <iostream>
#include <vector>
#include <string>
#include <map>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>

using namespace std;

static int max_experiments = 0;
static int signal_received = -1;
static const string good_addr = "74:1E:AF:AE:E4:8A";

static int help_arg = 0;
static int print_skips_arg = 0;
static int delay_arg = 5; // seconds
static int debug_arg = 0;

static struct option options[] = {
	{ "help",		0, &help_arg, 'h' },
	{ "print-skips",	0, &print_skips_arg, 'p' },
	{ "delay",		1, &delay_arg, 'd' },
	{ "debug",		0, &debug_arg, 'D' },
	{ 0, 0, 0, 0 }
};


#define EIR_NAME_SHORT              0x08  /* shortened local name */
#define EIR_NAME_COMPLETE           0x09  /* complete local name */
#define D(a) if (debug_arg) (a)

struct result_t {
    struct timeval timestamp;
    char addr[18];
    string name;
};

typedef vector<result_t> results_t;
typedef map<string, results_t> results_map_t;

enum result_type_t {
    RESULT_GOOD,
    RESULT_BAD,
    RESULT_SKIP,
    RESULT_DONE,
};


static string eir_parse_name(uint8_t *eir, size_t eir_len)
{
    size_t offset;
    string ret;

    offset = 0;
    while (offset < eir_len) {
        uint8_t field_len = eir[0];
        size_t name_len;

        /* Check for the end of EIR */
        if (field_len == 0) {
            break;
        }

        if (offset + field_len > eir_len) {
            goto failed;
        }

        switch (eir[1]) {
        case EIR_NAME_SHORT:
        case EIR_NAME_COMPLETE:
            name_len = field_len - 1;
            ret.copy((char*) &eir[2], name_len, 0);
            return ret;
        }

        offset += field_len + 1;
        eir += field_len + 1;
    }

failed:
    return "unknown";
}


static result_type_t record_result(int device, results_map_t &results)
{
    int len;
    unsigned char buf[HCI_MAX_EVENT_SIZE], *ptr;
    evt_le_meta_event *meta;
    le_advertising_info *info;
    struct timeval now;
    result_t result;

    /* Read the result from the fd */
    while ((len = read(device, buf, sizeof(buf))) < 0) {
        if (errno == EINTR && signal_received == SIGINT) {
            return RESULT_DONE;
        }

        if (errno == EAGAIN || errno == EINTR) {
            continue;
        }
        return RESULT_BAD;
    }

    ptr = buf + (1 + HCI_EVENT_HDR_SIZE);
    len -= (1 + HCI_EVENT_HDR_SIZE);

    meta = (evt_le_meta_event *) ptr;

    if (meta->subevent != 0x02) {
        return RESULT_BAD;
    }

    /* Extract the result and save it in the vector */
    gettimeofday(&result.timestamp, NULL);
    info = (le_advertising_info *) (meta->data + 1);
    ba2str(&info->bdaddr, result.addr);
    if (result.addr == good_addr) {
        result.name = eir_parse_name(info->data, info->length);
        results[result.addr].push_back(result);

        D(cout << "Record result: " 
               << result.addr << " " << result.name << endl);
        return RESULT_GOOD;
    }

    if (print_skips_arg) {
        cout << "Skipping: " << result.addr << endl;
    }

    return RESULT_SKIP;
}

static long tv2long(struct timeval tv)
{
    long ret = tv.tv_sec * 1000000;
    ret += tv.tv_usec;
    return ret;
}


static void print_results(int experiment_num, results_map_t &results)
{
    D(printf("Printing results for experiment #%d...\n", experiment_num));

    results_map_t::iterator i;
    for (i = results.begin(); i != results.end(); ++i) {
        string addr = i->first;
        
        results_t::iterator j;
        int count = i->second.size();
        long first = tv2long(i->second.front().timestamp);
        long last = tv2long(i->second.back().timestamp);
        cout << experiment_num << "," 
             << addr << "," 
             << count << "," 
             << first << "," 
             << last 
             << endl;
    }
    cout << endl;
}


//
// Main loop
//
static void experiment_loop(int device, uint8_t filter_type)
{
    int experiment_num;

    experiment_num = 1;
    while (0 == max_experiments || experiment_num <= max_experiments) {
        results_map_t results;
        long last_good_result = 0;

	while (1) {
            struct timeval tv;

            /* If we have some results and our last good result was
               more than delay_arg seconds ago, then
               end this experiment and go on to the next */
            if (!results.empty()) {
                gettimeofday(&tv, NULL);

                long now = tv2long(tv);
                long time_for_next = 
                    last_good_result + delay_arg * 1000000;
                D(printf("We have results:\n\ttime for next: %lu\n\tnow:           %lu\n",
                         time_for_next, now));

                if (now > time_for_next) {
                    D(printf("*** Time for next experiment!\n"));
                    break;
                }
            }

            fd_set fdset;
            struct timeval timeout;

            FD_ZERO(&fdset);
            FD_SET(device, &fdset);
            timeout.tv_sec = delay_arg;
            timeout.tv_usec = 0;

            int ret = select(device + 1, &fdset, NULL, NULL, &timeout);
            if (ret > 0) {
                /* If something was ready to read, process it */
                result_type_t ret = record_result(device, results);
                switch(ret) {
                case RESULT_GOOD:
                    gettimeofday(&tv, NULL);
                    last_good_result = tv2long(tv);
                    break;

                case RESULT_BAD:
                case RESULT_DONE:
                    return;

                case RESULT_SKIP:
                    continue;
                }
            } else if (0 == ret) {
                /* If nothing was ready, and if we have some previous
                   results, then end this experiment and go on to the
                   next */
                if (!results.empty()) {
                    break;
                }
            } else {
                /* Otherwise, there was an error.  Did someone hit
                   ctrl-C? */
                if (errno == EINTR && signal_received == SIGINT) {
                    return;
                }

                /* If it was a "just try again" kind of erro, then do
                   so */
                if (errno == EAGAIN || errno == EINTR) {
                    continue;
                }

                /* It was some other kind of error; we should probably
                   just abourt */
                perror("select failed");
                exit(1);
            }
        }

        /* Setup for next experiment */
        printf("Experiment %d done; looping to next...\n", experiment_num);
        print_results(experiment_num, results);
        results.clear();
        ++experiment_num;
    }
}


/*
 * Handler for SIGINT
 */
static void sigint_handler(int sig)
{
    /* Just record the signal; we'll check for it/handle it in the
       main loop */
    signal_received = sig;
}


static void run_experiments(int device, uint8_t filter_type)
{
    struct hci_filter nf, of;
    struct sigaction sa;
    socklen_t olen;
    int len;

    /* Get original flags */
    olen = sizeof(of);
    if (getsockopt(device, SOL_HCI, HCI_FILTER, &of, &olen) < 0) {
        perror("Could not get socket options");
        exit(1);
    }

    /* Set my filter flags */
    hci_filter_clear(&nf);
    hci_filter_set_ptype(HCI_EVENT_PKT, &nf);
    hci_filter_set_event(EVT_LE_META_EVENT, &nf);

    if (setsockopt(device, SOL_HCI, HCI_FILTER, &nf, sizeof(nf)) < 0) {
        perror("Could not set socket options");
        exit(1);
    }

    /* Catch if someone hits ctrl-C */
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags = SA_NOCLDSTOP;
    sa.sa_handler = sigint_handler;
    sigaction(SIGINT, &sa, NULL);

    /* Main loop */
    experiment_loop(device, filter_type);

done:
    /* Restore original flags */
    setsockopt(device, SOL_HCI, HCI_FILTER, &of, sizeof(of));
}


static void scan(int device)
{
    int err;
    uint8_t own_type = 0x00;
    uint8_t scan_type = 0x01;
    uint8_t filter_type = 0;
    uint8_t filter_policy = 0x00;
    uint16_t interval = htobs(0x0010);
    uint16_t window = htobs(0x0010);
    uint8_t filter_duplicates = 0;
    uint8_t enable = 0x01;
    int to = 1000;

    err = hci_le_set_scan_parameters(device, scan_type, interval, window,
                                     own_type, filter_policy, to);
    if (err < 0) {
        perror("Set scan parameters failed");
        exit(1);
    }

    /* Start the scan */
    err = hci_le_set_scan_enable(device, enable, filter_duplicates, to);
    if (err < 0) {
        perror("Enable scan failed");
        exit(1);
    }

    /* Run the experiments */
    run_experiments(device, filter_type);

    /* Stop the scan */
    enable = 0x00;
    err = hci_le_set_scan_enable(device, enable, filter_duplicates, to);
    if (err < 0) {
        perror("Disable scan failed");
        exit(1);
    }
}

int main(int argc, char* argv[])
{
    int device_id, device, i;

    while (-1 != (i = getopt_long(argc, argv, "", options, NULL))) {
        switch(i) {
        case 'd':
            delay_arg = atoi(optarg);
            printf("Got delay: %d\n", delay_arg);
            break;
        }
    }

    if (help_arg) {
        cout << argv[0] << " usage:" << endl
             << "--help         This help message" << endl
             << "--print-skips  Print address of devices that are skipped" << endl
             << "--delay        Delay (in seconds) between experiments" << endl
             << "--debug        Print debugging messages" << endl;
        exit(0);
    }

    device_id = hci_get_route(NULL);
    if (device_id < 0) {
        perror("Could not hci_get_route");
        exit(1);
    }

    device = hci_open_dev(device_id);
    if (device < 0) {
        perror("Could not open device");
        exit(1);
    }

    scan(device);

    return 0;
}
