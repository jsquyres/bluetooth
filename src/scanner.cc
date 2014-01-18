//
// Scanner tool for science experiments
//
// Jeff Squyres (c) 2013-2014
//
// Strongly influenced by hcitool.c from the bluez toolkit.
//

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <errno.h>
#include <sys/time.h>
#include <getopt.h>

#include <iostream>
#include <iomanip>
#include <vector>
#include <string>
#include <map>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>

#include "argv.h"

using namespace std;

static int max_experiments = 0;
static int signal_received = -1;
static string good_address;

static int help_arg = 0;
static int print_skips_arg = 0;
static int delay_arg = 5; // seconds
static int debug_arg = 0;
static char csv_filename[4096] = { '\0' };
static char web_dir[4096] = { '\0' };
static bool have_web_dir = false;
static bool web_msg_index = 0;
static FILE *csv_output = NULL;
static vector < string > labels;

static struct option options[] = {
	{ "help",		0, &help_arg, 'h' },
	{ "print-skips",	0, &print_skips_arg, 'p' },
	{ "debug",		0, &debug_arg, 'D' },
        // Need to get values for the next two, so don't specify a
        // variable to fill
	{ "filename",		1, 0, 'f' },
	{ "delay",		1, 0, 'd' },
	{ "address",		1, 0, 'a' },
	{ "webdir",		1, 0, 'w' },
	{ "labels",		1, 0, 'l' },
	{ 0, 0, 0, 0 }
};


#define EIR_NAME_SHORT              0x08  // shortened local name
#define EIR_NAME_COMPLETE           0x09  // complete local name
#define D(a) if (0 != debug_arg) (a)

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


//
// Parse data from le_advertising_info and get a name out of it
//
static string eir_parse_name(uint8_t *eir, size_t eir_len)
{
    size_t offset;
    string ret;
    char buffer[HCI_MAX_EVENT_SIZE];

    offset = 0;
    while (offset < eir_len) {
        uint8_t field_len = eir[0];
        size_t name_len;

        // Check for the end of EIR
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
            memset(buffer, 0, sizeof(buffer));
            memcpy(buffer, &eir[2], name_len);
            ret = buffer;
            return ret;
        }

        offset += field_len + 1;
        eir += field_len + 1;
    }

failed:
    return "unknown";
}


//
// Convert a struct timeval to a long long
//
static long long tv2long(struct timeval tv)
{
    long long ret = tv.tv_sec;
    ret *= 1000000;
    ret += tv.tv_usec;
    return ret;
}


//
// Handler for SIGINT
//
static void sigint_handler(int sig)
{
    // Just record the signal; we'll check for it/handle it in the
    // main loop
    signal_received = sig;
}


//
// Write the next file into the web message directory
//
static void write_web_message(string msg)
{
  FILE *fp;
  char *filename;

  if (!have_web_dir) {
    return;
  }

  asprintf(&filename, "%s/from-scanner-%d.txt", web_dir, web_msg_index++);
  unlink(filename);
  fp = fopen(filename, "w");
  fprintf(fp, msg.c_str());
  fclose(fp);
  free(filename);
  printf("Wrote web message: %s", msg.c_str());
}


//
// Read the data from a evt_le_meta_event and record it in the results
// map (if it's the type we want and it matches the good_address)
//
static result_type_t record_result(int device, results_map_t &results)
{
    int len;
    unsigned char buf[HCI_MAX_EVENT_SIZE], *ptr;
    evt_le_meta_event *meta;
    le_advertising_info *info;
    result_t result;

    // Read the result from the fd
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

    // Extract the result and save it in the vector
    gettimeofday(&result.timestamp, NULL);
    info = (le_advertising_info *) (meta->data + 1);
    ba2str(&info->bdaddr, result.addr);
    if (good_address.empty() || result.addr == good_address) {
        result.name = eir_parse_name(info->data, info->length);
        results[result.addr].push_back(result);

        D(cout << "Record result: " 
               << result.addr << " " << result.name << endl);
	if (have_web_dir) {
	  D(write_web_message("Record result: " + 
			      ((string) result.addr) + " " +
			      ((string) result.name) + "\n"));
	}
        return RESULT_GOOD;
    }

    if (print_skips_arg) {
        cout << "Skipping: " << result.addr << endl;
	if (have_web_dir) {
	  write_web_message("Skipping: " + ((string) result.addr) + "\n");
	}
    }

    return RESULT_SKIP;
}


//
// Loop through a map of results and print them all
//
static void print_results(string label, int experiment_num, results_map_t &results)
{
    D(printf("Printing results for experiment #%d...\n", experiment_num));

    results_map_t::iterator i;
    for (i = results.begin(); i != results.end(); ++i) {
        string addr = i->first;
        
        int count = i->second.size();
        struct timeval first = i->second.front().timestamp;
        struct timeval last = i->second.back().timestamp;

        // Find a non "unknown" name
        results_t::iterator j;
        string name = i->second.begin()->name;
        name = "unknown";
        if (name == "unknown") {
            for (j = i->second.begin(); j != i->second.end(); ++j) {
                if (j->name != "unknown") {
                    name = j->name;
                    break;
                }
            }
        }

        // Print it out
        cout << label << ","
             << experiment_num << ","
             << addr << "," 
             << name << ","
             << count << "," 
             << first.tv_sec << "."
             << setfill('0') << setw(6) << first.tv_usec << ","
             << last.tv_sec << "."
             << setfill('0') << setw(6) << last.tv_usec
             << endl;

        if (NULL != csv_output) {
            static bool first_time = true;
            if (first_time) {
                fprintf(csv_output, "Experiment name,Experiment number,Device address,Device name,Count,First timestamp,Second timestamp\n");
                first_time = false;
            }

            fprintf(csv_output, "%s,%u,%s,%s,%d,%u.%06u,%u.%06u\n",
                    label.c_str(),
                    experiment_num,
                    addr.c_str(),
                    name.c_str(),
                    count,
                    (unsigned int) first.tv_sec,
                    (unsigned int) first.tv_usec,
                    (unsigned int) last.tv_sec,
                    (unsigned int) last.tv_usec);
        }

	if (have_web_dir) {
	  char *msg;

	  asprintf(&msg, "%s,%u,%s,%s,%d,%u.%06u,%u.%06u\n",
                    label.c_str(),
                    experiment_num,
                    addr.c_str(),
                    name.c_str(),
                    count,
                    (unsigned int) first.tv_sec,
                    (unsigned int) first.tv_usec,
                    (unsigned int) last.tv_sec,
                    (unsigned int) last.tv_usec);
	  write_web_message(msg);
	  free(msg);
	}
    }
}


//
// Determine if it has been <delay_arg> seconds since the last good
// result was collected
//
static bool time_for_next_experiment(bool have_results,
                                     long long last_good_result)
{
    // If we have some results and our last good result was
    // more than delay_arg seconds ago, then
    // end this experiment and go on to the next */
    if (!have_results) {
        return false;
    }

    struct timeval tv;
    gettimeofday(&tv, NULL);

    long long now = tv2long(tv);
    long long time_for_next = last_good_result + delay_arg * 1000000;
    D(printf("We have results:\n"
             "\ttime for next: %llu\n"
             "\tnow:           %llu\n",
             time_for_next, now));

    if (now > time_for_next) {
        D(printf("*** Time for next experiment!\n"));
        return true;
    }

    return false;
}


//
// Main experiment loop
//
static void experiment_loop(int device, uint8_t filter_type)
{
    int experiment_num;

    experiment_num = 1;
    while (0 == max_experiments || experiment_num <= max_experiments) {
        results_map_t results;
        long long last_good_result = 0;
        string label = "Unknown";

        // Keep looping in this experiment until it is done
	while (!time_for_next_experiment(!results.empty(), last_good_result)) {

            // Setup for the select
            fd_set fdset;
            struct timeval timeout;

            FD_ZERO(&fdset);
            FD_SET(fileno(stdin), &fdset);
            FD_SET(device, &fdset);
            timeout.tv_sec = delay_arg;
            timeout.tv_usec = 0;
            int ret = select(device + 1, &fdset, NULL, NULL, &timeout);

            if (ret > 0) {
                // If something was ready on stdin, go read a line to
                // label this experiment
                if (FD_ISSET(fileno(stdin), &fdset)) {
                    printf("Label for experiment: ");
                    fflush(stdout);
                    cin >> label;
                    cout << "Got new label: " << label << endl;
                } else {
                    // If something was ready to read, process it
                    struct timeval tv;
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
                }
            } else if (0 == ret) {
                // If nothing was ready, and if we have some previous
                // results, then end this experiment and go on to the
                // next
                if (!results.empty()) {
                    break;
                }
            } else {
                // Otherwise, there was an error.  Did someone hit
                // ctrl-C?
                if (errno == EINTR && signal_received == SIGINT) {
                    return;
                }

                // If it was a "just try again" kind of erro, then do
                // so
                if (errno == EAGAIN || errno == EINTR) {
                    continue;
                }

                // It was some other kind of error; we should probably
                // just abourt
                perror("select failed");
                exit(1);
            }
        }

        // Setup for next experiment
        D(printf("Experiment %d done; looping to next...\n", experiment_num));
        print_results(label, experiment_num, results);
        results.clear();
        ++experiment_num;
        label = "Unknown";
    }
}


//
// Set the set socket and filter options, then run the experiment loop
//
static void run_experiments(int device, uint8_t filter_type)
{
    struct hci_filter nf, of;
    struct sigaction sa;
    socklen_t olen;

    // Get original flags
    olen = sizeof(of);
    if (getsockopt(device, SOL_HCI, HCI_FILTER, &of, &olen) < 0) {
        perror("Could not get socket options");
        exit(1);
    }

    // Set my filter flags
    hci_filter_clear(&nf);
    hci_filter_set_ptype(HCI_EVENT_PKT, &nf);
    hci_filter_set_event(EVT_LE_META_EVENT, &nf);

    if (setsockopt(device, SOL_HCI, HCI_FILTER, &nf, sizeof(nf)) < 0) {
        perror("Could not set socket options");
        exit(1);
    }

    // Catch if someone hits ctrl-C
    memset(&sa, 0, sizeof(sa));
    sa.sa_flags = SA_NOCLDSTOP;
    sa.sa_handler = sigint_handler;
    sigaction(SIGINT, &sa, NULL);

    // Call the main loop
    experiment_loop(device, filter_type);

    // Restore original flags
    setsockopt(device, SOL_HCI, HCI_FILTER, &of, sizeof(of));
}


//
// Startup the LE scan, run the experiments, and then stop the scan
//
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

    // Start the scan
    err = hci_le_set_scan_enable(device, enable, filter_duplicates, to);
    if (err < 0) {
        perror("Enable scan failed");
        exit(1);
    }

    // Run the experiments
    run_experiments(device, filter_type);

    // Stop the scan
    enable = 0x00;
    err = hci_le_set_scan_enable(device, enable, filter_duplicates, to);
    if (err < 0) {
        perror("Disable scan failed");
        exit(1);
    }
}


//
// Break the labels into a comma-separated list and load them into a vector
//
static void load_labels(char *arg)
{
  int i;
  char **tokens;

  tokens = opal_argv_split_inter(arg, ',', 0);
  for (i = 0; tokens[i] != NULL; ++i) {
    cout << "Saving label: " << tokens[i] << endl;
    labels.push_back(tokens[i]);
  }

  // JMS I know this leaks memory.  Will fix later...
}


//
// Print the help message
//
static void show_help(const string argv0)
{
    cout << argv0 << " usage:" << endl << endl
         << "--help               This help message" << endl
         << "--print-skips        Print address of devices that are skipped" << endl
         << "--delay N            Delay N seconds between experiments" << endl
         << "--address X          Only monitor for address X (e.g., AA:BB:CC:DD:EE:FF)" << endl
         << "--filename FILENAME  Name the output CSV file" << endl
         << "--webdir DIRNAME     Name of the directory for the web messag files" << endl
         << "--labels LBL1,LBL2,... List of labels to use" << endl
         << "--debug              Print debugging messages" << endl;
}


//
// main
//
int main(int argc, char* argv[])
{
    int device_id, device, i;

    while (-1 != (i = getopt_long(argc, argv, "", options, NULL))) {
        D(printf("Analyzing: 0x%x\n", i));
        switch(i) {
        case 'd':
            delay_arg = atoi(optarg);
            D(printf("Got delay: %d\n", delay_arg));
            break;

        case 'a':
            good_address = optarg;
            D(printf("Got address: %s\n", good_address.c_str()));
            break;

        case 'f':
            strcpy(csv_filename, optarg);
            break;

        case 'w':
            strcpy(web_dir, optarg);
	    have_web_dir = true;
            break;

	case 'l':
            load_labels(optarg);
            break;

        case '?':
            show_help(argv[0]);
            exit(1);
        }
    }

    if (help_arg) {
        show_help(argv[0]);
        exit(0);
    }

    // If we got a output CSV filename, open it
    if ('\0' != csv_filename[0]) {
        csv_output = fopen(csv_filename, "w");
        if (NULL == csv_output) {
            fprintf(stderr, "Failed to open file: %s\n", csv_filename);
            perror("fopen");
            exit(1);
        }
        cout << "Writing output to file: " << csv_filename << endl;
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

    // If we have an output file, close it
    if (NULL != csv_output) {
        fclose(csv_output);
        cout << "Wrote output to filename: " << csv_filename << endl;
    }

    return 0;
}
