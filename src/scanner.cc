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
#include <fstream>
#include <sstream>
#include <iomanip>
#include <vector>
#include <string>
#include <map>
#include <list>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>

#include "argv.h"

using namespace std;

static int experiment_num = 0;
static int signal_received = -1;
static string good_address;

static int help_arg = 0;
static int print_skips_arg = 0;
static int debug_arg = 0;
static char csv_filename[4096] = { '\0' };
static ofstream csv_output;
static list<string> labels;

static struct option options[] = {
    { "help",		0, &help_arg, 'h' },
    { "print-skips",	0, &print_skips_arg, 'p' },
    { "debug",		0, &debug_arg, 'D' },
    // Need to get values for these, so don't specify a variable
    // to fill
    { "filename",	1, 0, 'f' },
    { "address",	1, 0, 'a' },
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
// Handler for SIGINT
//
static void sigint_handler(int sig)
{
    // Just record the signal; we'll check for it/handle it in the
    // main loop
    signal_received = sig;
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
        return RESULT_GOOD;
    }

    if (print_skips_arg) {
        cout << "Skipping: " << result.addr << endl;
    }

    return RESULT_SKIP;
}


//
// Check to see if there's anything to read on stdin.  If there is,
// and it's not a blank line, then use that as the next label.
//
static void check_stdin(void)
{
    char input[4096];
    fd_set fdset;
    FD_ZERO(&fdset);
    struct timeval tv = { 0, 0 };

    FD_SET(fileno(stdin), &fdset);
    int ret = select(fileno(stdin) + 1, &fdset, NULL, NULL, &tv);

    // If there's something to read, do so
    if (1 == ret) {
        memset(input, '\0', sizeof(input));
        fgets(input, sizeof(input) - 1, stdin);
        if (input[strlen(input) - 1] == '\n') {
            input[strlen(input) - 1] = '\0';
        }

        // If we didn't read a blank line, save it as the next label
        if (input[0] != '\0') {
            D(cout << "Got new label: " << input << endl);
            labels.push_front(input);
        }
    }
}


//
// Remove the next label from the list of labels and set it as the
// current label
//
static string get_next_label(void)
{
    string label;

    check_stdin();

    if (labels.empty()) {
        ostringstream ostr;
        ostr << "Experiment " << experiment_num;
        label = ostr.str();
    } else {
        label = labels.front();
        labels.pop_front();
    }

    D(cout << "Got next experiment label " << label << endl);

    return label;
}


//
// Output the first line of the CSV file, with the column headings
//
static void output_csv_first_line(void)
{
    static bool first_time = true;
    if (first_time && csv_output.is_open()) {
        csv_output << "Experiment name,Experiment number,"
                   << "Device address,Device name,Count,"
                   << "First timestamp,Second timestamp" << endl;
        first_time = false;
    }
}


//
// Loop through a map of results and print them all
//
static void print_results(int experiment_num, results_map_t &results)
{
    ostringstream oss;
    string str, label;

    // Get the label to print for this experiment
    label = get_next_label();

    D(cout << "Printing results for experiment #" << experiment_num
           << " (" << label << ")" << endl);

    // If we have no results to print, then print a "zero line"
    if (results.empty()) {
        oss << label << ","
            << experiment_num << ","
            << "00:00:00:00:00:00,no-device-seen,0,0.0,0.0" << endl;
        str = oss.str();

        // Output to stdout
        cout << str;

        // Output to the CSV file
        if (csv_output.is_open()) {
            output_csv_first_line();
            csv_output << str;
        }

        return;
    }

    // Otherwise, iterate and print all the results
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

        // Render the result
        oss << label << ","
            << experiment_num << ","
            << addr << ","
            << name << ","
            << count << ","
            << first.tv_sec << "."
            << setfill('0') << setw(6) << first.tv_usec << ","
            << last.tv_sec << "."
            << setfill('0') << setw(6) << last.tv_usec
            << endl;
        str = oss.str();

        // Output to stdout
        cout << str;

        // Output to the CSV file
        if (csv_output.is_open()) {
            output_csv_first_line();
            csv_output << str;
        }
    }
}


//
// Main experiment loop
//
static void experiment_loop(int device, uint8_t filter_type)
{
    while (1) {
        results_map_t results;
        string label;

        // Get the label for this experiment
        ++experiment_num;
	label = get_next_label();
        D(cout << "Starting experiment " << label << endl);

        // Keep looping in this experiment until it i
        while (1) {

            // Setup for the select
            fd_set fdset;
            FD_ZERO(&fdset);
            FD_SET(fileno(stdin), &fdset);
            FD_SET(device, &fdset);
            int ret = select(device + 1, &fdset, NULL, NULL, NULL);

            if (ret > 0) {
                // If something was ready on stdin, end the experiment
                if (FD_ISSET(fileno(stdin), &fdset)) {
                    break;
                }

                // Otherwise, there was something ready to read from
                // the device
                else {
                    result_type_t ret = record_result(device, results);
                    switch(ret) {
                    case RESULT_GOOD:
                        break;

                    case RESULT_BAD:
                    case RESULT_DONE:
                        return;

                    case RESULT_SKIP:
                        continue;
                    }
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
                // just abort
                perror("select failed");
                exit(1);
            }
        }

        // End the current experiment
        D(cout << "Experiment " << experiment_num
               << " done (" << label
               << "); looping to next..." << endl);
        print_results(experiment_num, results);
        results.clear();
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
// Print the help message
//
static void show_help(const string argv0)
{
    cout << argv0 << " usage:" << endl << endl
         << "--help               This help message" << endl
         << "--print-skips        Print address of devices that are skipped" << endl
         << "--address X          Only monitor for address X (e.g., AA:BB:CC:DD:EE:FF)" << endl
         << "--filename FILENAME  Name the output CSV file" << endl
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
        case 'a':
            good_address = optarg;
            D(printf("Got address: %s\n", good_address.c_str()));
            break;

        case 'f':
            strcpy(csv_filename, optarg);
            D(printf("Got CSV filename: %s\n", csv_filename));
            break;

	case 'l':
            labels = opal_argv_split_inter(optarg, ',', 0);
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
        csv_output.open(csv_filename, ios::out);
        if (!csv_output.is_open()) {
            fprintf(stderr, "Failed to open file: %s\n", csv_filename);
            perror("fopen");
            exit(1);
        }
        cout << "Writing output to file: " << csv_filename << endl;
    }

    // Open up the device
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

    // Do the scans
    scan(device);

    // If we have an output file, close it
    if (csv_output.is_open()) {
        csv_output.close();
        cout << "Wrote output to filename: " << csv_filename << endl;
    }

    return 0;
}
